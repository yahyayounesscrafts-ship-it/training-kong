local operations = require "kong.db.migrations.operations.200_to_210"


local plugin_entities = {
  {
    name = "check_referer",
    primary_key = "id",
    uniques = {"consumer_id"},
    fks = {{name = "consumer", reference = "consumers", on_delete = "cascade"}},
  }
}


return operations.ws_migrate_plugin(plugin_entities)
