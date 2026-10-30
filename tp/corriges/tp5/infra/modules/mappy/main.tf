module "configure" {
  source = "../service"
  service_name = var.service_name
  routes = var.routes
  host = var.service_host
  port = var.service_port
  host_path = var.host_path
  domain = var.domain
  filelog_path = var.filelog_path
}
