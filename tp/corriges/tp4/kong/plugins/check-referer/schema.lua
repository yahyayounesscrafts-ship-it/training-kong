local typedefs = require "kong.db.schema.typedefs"


return {
  name = "check-referer",
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          -- laisser passer les requêtes sans en-tête Referer (ex : appels serveur à serveur)
          { allow_empty_referer = { type = "boolean", required = true, default = false } },
          -- comparer la regex à l'hôte du Referer uniquement, en l'ancrant (^...$)
          { match_host_only = { type = "boolean", required = true, default = false } },
        },
    }, },
  },
}
