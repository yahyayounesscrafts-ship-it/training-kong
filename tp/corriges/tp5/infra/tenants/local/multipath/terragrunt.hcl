terraform {
  source = "../../..//modules/mappy"
}

locals {
  tenant = read_terragrunt_config("../local.hcl")
  service = read_terragrunt_config("../../common/multipath.hcl")
}

inputs = merge(
local.tenant.inputs,
local.service.inputs
)
