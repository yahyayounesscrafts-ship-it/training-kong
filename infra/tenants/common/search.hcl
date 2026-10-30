inputs = {
  service_name = "Search"
  host_path = "/"
  routes = {
    api-search-base = {
      paths: ["/search/1.0/find"]
      hosts: ["api-search"]
      check_referer: true
      key_auth: true
      file_log: true
      cors: true
      acl_groups: ["front-search"]
      rate_limit_minutes: 100
    },
    api-search-suggest = {
      paths: ["/suggest/1.2/suggest"]
      hosts: ["api-search"]
      check_referer: true
      key_auth: true
      file_log: true
      cors: true
      acl_groups: ["front-suggest"]
      rate_limit_minutes: 100
    }
  }
}

