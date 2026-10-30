resource "kong_consumer" "consumer" {
  for_each = var.consumers

  username = each.key
}

resource "kong_consumer_plugin_config" "key_auth" {
  for_each = var.consumers

  consumer_id = kong_consumer.consumer[each.key].id
  plugin_name = "key-auth"
  config_json = jsonencode({ key = each.value.api_key })
}

# Pas de ressource dédiée aux ACL dans ce provider : on passe par l'endpoint
# générique POST /consumers/{id}/acls, une ressource par couple (consumer, groupe)
locals {
  acl_groups = merge([
    for name, c in var.consumers : {
      for g in c.acl_groups : "${name}/${g}" => { consumer = name, group = g }
    }
  ]...)
}

resource "kong_consumer_plugin_config" "acl" {
  for_each = local.acl_groups

  consumer_id = kong_consumer.consumer[each.value.consumer].id
  plugin_name = "acls"
  config_json = jsonencode({ group = each.value.group })
}

# Entité du plugin maison : POST /consumers/{id}/check-referer
resource "kong_consumer_plugin_config" "check_referer" {
  for_each = { for name, c in var.consumers : name => c if c.referer != "" }

  consumer_id = kong_consumer.consumer[each.key].id
  plugin_name = "check-referer"
  config_json = jsonencode({ referer = each.value.referer })
}
