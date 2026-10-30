variable "service_name" {
  type        = string
  description = "Service Name"
}

variable "service_host" {
  type        = string
  description = "Hostname"
}

variable "host_path" {
  type        = string
  description = "host path"
}

variable "filelog_path" {
  type        = string
}

variable "domain" {
  type        = string
}

variable "kong_admin_uri" {
  type        = string
  description = "kong admin uri"
}

variable "routes" {
  type = map(object({
    paths        = list(string)
    hosts        = list(string)
    check_referer = bool
    key_auth = bool
    file_log = bool
    cors = bool
    acl_groups = list(string)
    rate_limit_minutes = number
  }))
}

variable "service_port" {
  type        = number
  description = "Port of the upstream service"
  default     = 80
}
