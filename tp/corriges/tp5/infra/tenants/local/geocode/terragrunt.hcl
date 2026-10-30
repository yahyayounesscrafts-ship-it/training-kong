terraform {
  source = "../../..//modules/mappy"
}

locals {
  tenant = read_terragrunt_config("../local.hcl")
  service = read_terragrunt_config("../../common/geocode.hcl")
}

inputs = merge(
  local.tenant.inputs,
  local.service.inputs,
  # en local, httpbin ne sert que /anything/... : on y préfixe les chemins
  { host_path = "/anything" }
)
