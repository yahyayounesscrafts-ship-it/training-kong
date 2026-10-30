inputs = {
  service_name = "Geoentity"
  host_path = "/"
  routes = {
    poi = {
      paths: ["/"]
      hosts: ["api-poi"]
      check_referer: true
      key_auth: false
      file_log: true
      cors: true
      acl_groups: ["back-poi"]
      rate_limit_minutes: 100
    }
  }
}

