resource "kong_route" "route" {
  protocols       = [ "http" ]
  methods         = [ "GET", "OPTIONS" ]
  paths           = var.route.paths
  hosts           = formatlist("%s.${var.domain}", var.route.hosts)
  strip_path      = false
  preserve_host   = true
  regex_priority  = 1
  service_id  = var.service_id
}

resource "kong_plugin" "route_acl_openbar_plugin" {
  count = length(var.route.acl_groups) > 0 ? 1 : 0

  name = "acl"
  route_id = kong_route.route.id
  config_json = <<EOT
    {
        "allow": ${jsonencode(var.route.acl_groups)},
        "hide_groups_header": true
    }
EOT
}

resource "kong_plugin" "check_referer_service" {
  count = var.route.check_referer ? 1 : 0

  name = "check-referer"
  route_id = kong_route.route.id
}

resource "kong_plugin" "service_api_key_plugin" {
  count = var.route.key_auth ? 1 : 0

  name = "key-auth"
  route_id = kong_route.route.id
  config_json = <<EOT
    {
        "run_on_preflight": false,
        "key_names": ["apikey"],
        "key_in_header": true
    }
EOT
}

resource "kong_plugin" "route_rate_limited_plugin" {
  count = var.route.rate_limit_minutes > 0 ? 1 : 0

  name = "rate-limiting"
  route_id = kong_route.route.id
  config_json = <<EOT
    {
        "minute": ${var.route.rate_limit_minutes},
        "policy": "local",
        "limit_by": "ip"
    }
EOT
}

resource "kong_plugin" "file-log" {
  count = var.route.file_log ? 1 : 0
  route_id = kong_route.route.id
  name        = "file-log"
  config_json = <<EOT
    {
      "path": "${var.filelog_path}"
    }
EOT
}

resource "kong_plugin" "cors_plugin" {
  name = "cors"
  count = var.route.cors ? 1 : 0
  route_id = kong_route.route.id
  config_json = <<EOT
    {
        "origins": ["*"],
        "headers": ["apikey"],
        "preflight_continue": false,
        "credentials": true
    }
EOT
}
