local PLUGIN_NAME = "check-referer"

local handler = require "kong.plugins.check-referer.handler"

-- helper function to validate data against a schema
local validate do
  local validate_entity = require("spec.helpers").validate_plugin_config_schema
  local plugin_schema = require("kong.plugins."..PLUGIN_NAME..".schema")

  function validate(data)
    return validate_entity(data, plugin_schema)
  end
end


describe(PLUGIN_NAME .. ": (matcher)", function()

  it("returns true when regex match referer", function()
    local regex = "tot.*"
    local ok, err = handler.matcher(nil, regex, "toto")
    assert.is_nil(err)
    assert.is_truthy(ok)
  end)

  it("returns true when regex match referer - 2", function()
    local regex = "mappy.com"
    local ok, err = handler.matcher(nil, regex, "mappy.com")
    assert.is_nil(err)
    assert.is_truthy(ok)
  end)

  it("returns false when regex does't match referer", function()
      local regex = "mappy.com"
      local ok, err = handler.matcher(nil, regex, "mappy.fr")
      assert.is_nil(err)
      assert.is_falsy(ok)
    end)

end)

describe(PLUGIN_NAME .. ": (schema)", function()

  it("accepts empty config", function()
    local ok, err = validate({})
    assert.is_nil(err)
    assert.is_truthy(ok)
  end)

  it("rejects config", function()
    local ok, err = validate({something = "rejected"})
    assert.is_nil(ok)
    local errfn = function()
      error({ config = { something = 'unknown field' } })
    end
    assert.has_error(errfn, err)
  end)

  it("defaults new options to false", function()
    local entity = assert(validate({}))
    assert.is_false(entity.config.allow_empty_referer)
    assert.is_false(entity.config.match_host_only)
  end)

  it("accepts boolean options", function()
    local entity = assert(validate({ allow_empty_referer = true, match_host_only = true }))
    assert.is_true(entity.config.allow_empty_referer)
    assert.is_true(entity.config.match_host_only)
  end)

  it("rejects non boolean options", function()
    local ok, err = validate({ match_host_only = "yes" })
    assert.is_nil(ok)
    assert.same({ config = { match_host_only = "expected a boolean" } }, err)
  end)
end)

describe(PLUGIN_NAME .. ": (matcher, nil referer)", function()
  it("returns false without error when there is no referer", function()
    assert.is_false(handler.matcher(nil, "mappy.com", nil))
  end)
end)
