variable "kong_admin_uri" {
  type        = string
  description = "kong admin uri"
}

variable "consumers" {
  type = map(object({
    api_key    = string
    acl_groups = list(string)
    referer    = string
  }))
}
