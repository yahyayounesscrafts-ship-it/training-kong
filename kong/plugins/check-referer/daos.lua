local typedefs = require "kong.db.schema.typedefs"

return {
  check_referer = {
    primary_key = { "id" },
    name = "check_referer",
    workspaceable = true,
    admin_api_name = "check-referers",
    admin_api_nested_name = "check-referer",
    cache_key = { "consumer" },
    fields = {
      { id = typedefs.uuid },
      { created_at = typedefs.auto_timestamp_s },
      { consumer = { type = "foreign", reference = "consumers", required = true, unique = true, on_delete = "cascade", }, },
      { referer = { type = "string", is_regex = true, required = true }},
    },
  },
}

