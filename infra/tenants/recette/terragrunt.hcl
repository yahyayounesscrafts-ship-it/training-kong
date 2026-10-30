terraform {
  source = "../..//modules/kong"
}

locals {
  tenant = read_terragrunt_config("./snap.hcl")
}

inputs = merge(
local.tenant.inputs
)
