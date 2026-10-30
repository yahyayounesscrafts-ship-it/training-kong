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

      -- route avec match_host_only : la regex doit couvrir tout l'hôte du Referer
      local route3 = bp.routes:insert({
        paths = { "/host-only" },
      })
      bp.plugins:insert {
        name = PLUGIN_NAME,
        route = { id = route3.id },
        config = { match_host_only = true },
      }
      bp.plugins:insert {
        name     = "key-auth",
        route = { id = route3.id },
      }

      -- route avec allow_empty_referer : une requête sans Referer est acceptée
      local route4 = bp.routes:insert({
        paths = { "/empty-ok" },
      })
      bp.plugins:insert {
        name = PLUGIN_NAME,
        route = { id = route4.id },
        config = { allow_empty_referer = true },
      }
      bp.plugins:insert {
        name     = "key-auth",
        route = { id = route4.id },
      }

      db.check_referer:insert {
        consumer =  { id = consumer.id},
        referer  = "mappy\\.com",
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

      describe("and the default config", function()
        -- documente un comportement non souhaité : la regex n'est pas ancrée
        it("lets a referer containing the allowed value elsewhere through", function()
          local r = client:get("/test", {
            headers = { apiKey = "kong", Referer = "https://evil.com/?mappy.com" }
          })
          assert.response(r).has.status(200)
        end)
      end)

      describe("and match_host_only", function()
        local function get(referer)
          return client:get("/host-only", {
            headers = { apiKey = "kong", Referer = referer }
          })
        end

        it("accepts the allowed host, whatever the path, port or case", function()
          assert.response(get("https://mappy.com/carte?x=1")).has.status(200)
          assert.response(get("https://MAPPY.com:8443/")).has.status(200)
        end)

        it("rejects the allowed value in the query string", function()
          assert.response(get("https://evil.com/?mappy.com")).has.status(403)
        end)

        it("rejects a sub-domain of an attacker", function()
          assert.response(get("https://mappy.com.evil.com/")).has.status(403)
        end)

        it("rejects the allowed value as userinfo", function()
          assert.response(get("https://mappy.com@evil.com/")).has.status(403)
        end)

        it("rejects a referer that is not an URL", function()
          assert.response(get("mappy.com")).has.status(403)
        end)
      end)

      describe("and allow_empty_referer", function()
        it("accepts a request without referer", function()
          local r = client:get("/empty-ok", {
            headers = { apiKey = "kong" }
          })
          assert.response(r).has.status(200)
        end)

        it("still rejects a wrong referer", function()
          local r = client:get("/empty-ok", {
            headers = { apiKey = "kong", Referer = "https://evil.com/" }
          })
          assert.response(r).has.status(403)
        end)
      end)
    end)
  end)
end
