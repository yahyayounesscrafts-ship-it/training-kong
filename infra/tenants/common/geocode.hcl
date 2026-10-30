inputs = {
  service_name = "Geocode"
  host_path = "/"
  routes = {
    api-search-reverse-front = {
      paths: ["/reverse/1.0/find"]
      hosts: ["api-search"]
      check_referer: true
      key_auth: true
      file_log: true
      cors: true
      acl_groups: ["front-iti", "front-reverse"]
      rate_limit_minutes: 100
    },
    api-search-forward-front = {
      paths: ["/forward/1.0/find"]
      hosts: ["api-search"]
      check_referer: true
      key_auth: true
      file_log: true
      cors: true
      acl_groups: ["front-iti", "front-forward"]
      rate_limit_minutes: 100
    },
    api-search-reverse-back = {
      paths: ["/reverse/1.0/find"]
      hosts: ["api-search-batch"]
      check_referer: false
      key_auth: true
      file_log: true
      cors: true
      acl_groups: ["front-iti", "back-reverse"]
      rate_limit_minutes: 0
    },
    api-search-forward-back = {
      paths: ["/forward/1.0/find"]
      hosts: ["api-search-batch"]
      check_referer: false
      key_auth: true
      file_log: true
      cors: true
      acl_groups: ["front-iti", "back-forward"]
      rate_limit_minutes: 0
    }
  }
}

