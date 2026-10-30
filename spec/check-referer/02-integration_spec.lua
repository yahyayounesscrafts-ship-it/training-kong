local helpers = require "spec.helpers"

local PLUGIN_NAME = "check-referer"

for _, strategy in helpers.each_strategy() do
  describe(PLUGIN_NAME .. ": (access) [#" .. strategy .. "]", function()
    local client

    lazy_setup(function()

      local bp, db = helpers.get_db_utils(
        strategy, {
          "routes",
          "services",
          "plugins",
          "consumers",
          "keyauth_credentials",
          "check_referer"
        },
        { PLUGIN_NAME }
      )

      local route1 = bp.routes:insert({
        paths = { "/route" },
      })
      -- add the plugin to test to the route we created
      bp.plugins:insert {
        name = PLUGIN_NAME,
        route = { id = route1.id },
        config = {},
      }

      local route2 = bp.routes:insert({
        paths = { "/test" },
      })
      bp.plugins:insert {
        name = PLUGIN_NAME,
        route = { id = route2.id },
        config = {},
      }
      local consumer = bp.consumers:insert {
        username = "bob"
      }
      bp.plugins:insert {
        name     = "key-auth",
        route = { id = route2.id },
      }
      bp.keyauth_credentials:insert {
        key      = "kong",
        consumer = { id = consumer.id },
      }

      db.check_referer:insert {
        consumer =  { id = consumer.id},
        referer  = "mappy.com",
      }

      -- start kong
      assert(helpers.start_kong({
        -- set the strategy
        database   = strategy,
        -- use the custom test template to create a local mock server
        nginx_conf = "spec/fixtures/custom_nginx.template",
        -- make sure our plugin gets loaded
        plugins = "bundled," .. PLUGIN_NAME,
      }))
    end)

    lazy_teardown(function()
      helpers.stop_kong(nil, true)
    end)

    before_each(function()
      client = helpers.proxy_client()
    end)

    after_each(function()
      if client then client:close() end
    end)



    describe("without a consumer", function()
      it("return a 401 error", function()
        local r = client:get("/route", {
          headers = { }
        })
        assert.response(r).has.status(401)
        local json = assert.response(r).has.jsonbody()
        assert.equal("You cannot consume this service", json.message)
      end)
    end)

    describe("with a consumer", function()
      describe("and no header referer", function()
        it("return a 403 error", function()
          local r = client:get("/test", {
            headers = { apiKey = "kong"}
          })
          assert.response(r).has.status(403)
          local json = assert.response(r).has.jsonbody()
          assert.equal("You cannot consume this service", json.message)
        end)
      end)
      describe("and an invalid header referer", function()
        it("return a 403 error", function()
          local r = client:get("/test", {
            headers = { apiKey = "kong", referer = "toto.com"}
          })
          assert.response(r).has.status(403)
          local json = assert.response(r).has.jsonbody()
          assert.equal("You cannot consume this service", json.message)
        end)
      end)
      describe("and a valid header referer", function()
        it("return a 200", function()
          local r = client:get("/test", {
            headers = { apiKey = "kong", Referer = "mappy.com"}
          })
          assert.response(r).has.status(200)
        end)
      end)
    end)
  end)
end
