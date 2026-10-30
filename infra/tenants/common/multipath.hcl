inputs = {
  service_name = "Multipath"
  host_path = "/"
  routes = {
    multipath-front = {
      paths: ["/"]
      hosts: ["api-iti"]
      check_referer: true
      key_auth: true
      file_log: true
      cors: true
      acl_groups: ["front-iti"]
      rate_limit_minutes: 100
    },
    multipath-batch = {
      paths: ["/"]
      hosts: ["api-iti-batch"]
      check_referer: false
      key_auth: false
      file_log: true
      cors: true
      acl_groups: ["mappy-iti"]
      rate_limit_minutes: 0
    }
  }
}

