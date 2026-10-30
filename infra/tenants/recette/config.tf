terraform {
  required_providers {
    kong = {
      source = "philips-labs/kong"
      version = "5.521.2"
    }
  }
}

provider "kong" {
  kong_admin_uri = "http://recette-kong-admin-002.mappy.priv:8001"
}
