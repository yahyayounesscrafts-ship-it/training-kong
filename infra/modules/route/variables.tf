variable "route" {
  type = object({
    paths        = list(string)
    hosts        = list(string)
    check_referer = bool
    key_auth = bool
    file_log = bool
    cors = bool
    acl_groups = list(string)
    rate_limit_minutes = number
  })
}

variable "filelog_path" {
  type        = string
}

variable "domain" {
  type        = string
}

variable "service_id" {
  type        = string
  description = "service id"
}
