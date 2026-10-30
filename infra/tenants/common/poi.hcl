inputs = {
  service_name = "Poi"
  host_path = "/"
  routes = {
    poi = {
      paths: ["/"]
      hosts: ["api-poi-batch"]
      check_referer: false
      key_auth: false
      file_log: true
      cors: true
      acl_groups: ["back-generik-poi"]
      rate_limit_minutes: 0
    }
  }
}

