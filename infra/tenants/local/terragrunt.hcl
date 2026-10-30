terraform {
  source = "../..//modules/kong"
}

locals {
  tenant = read_terragrunt_config("./local.hcl")
}

inputs = merge(
local.tenant.inputs
)
