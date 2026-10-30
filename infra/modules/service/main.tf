resource "kong_service" "service" {
  name        = var.service_name
  protocol    = "http"
  port        = 80
  host        = var.host
  path        = var.host_path
  retries     = 5
  connect_timeout = 1000
  write_timeout   = 2000
  read_timeout    = 3000
}

module "route" {
  for_each = var.routes

  source = "../route/"
  route = each.value
  domain = var.domain
  service_id = kong_service.service.id
  filelog_path = var.filelog_path
}
