inputs = {
  service_name = "MapVectoRaster"
  host_path = "/"
  routes = {
    api-map-1 = {
      paths: ["/"]
      hosts: ["api-map"]
      check_referer: true
      key_auth: true
      file_log: true
      cors: true
      acl_groups: ["front-map"]
      rate_limit_minutes: 0
    }
  }
}

