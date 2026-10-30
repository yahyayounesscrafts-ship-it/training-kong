resource "kong_service" "service_kong_by_kong" {
  name        = "kong"
  protocol    = "http"
  port        = 8001
  host        = "127.0.0.1"
  path        = "/"
}

resource "kong_route" "route_kong_by_kong" {
  protocols       = [ "http", "https"]
  methods         = [ "GET", "OPTIONS", "POST", "PUT", "DELETE" ]
  paths           = ["/admin"]
 # hosts           = ["127.0.0.1"]
  strip_path      = true
  preserve_host   = false
  regex_priority  = 1
  service_id  = kong_service.service_kong_by_kong.id
}

resource "kong_plugin" "service_api_key_plugin" {
  name = "key-auth"
  service_id = kong_service.service_kong_by_kong.id
  config_json = <<EOT
    {
        "run_on_preflight": false,
        "key_names": ["apikey"],
        "key_in_header": true
    }
EOT
}


resource "kong_consumer_plugin_config" "consumer_kong_key_config" {
  consumer_id = kong_consumer.consumer_for_kong.id
  plugin_name = "key-auth"
  config_json = <<EOT
    {
        "key": "UNE-CLE-KONG"
    }
EOT
}

resource "kong_plugin" "global_prometheus_plugin" {
  name = "prometheus"
}

resource "kong_consumer" "consumer_for_kong" {
  username  = "ConsumerKong"
  custom_id = "21"
}
