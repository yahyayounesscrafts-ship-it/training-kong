terraform {
  source = "../../..//modules/mappy"
}

locals {
  tenant = read_terragrunt_config("../snap.hcl")
  service = read_terragrunt_config("../../common/map-vecto-raster.hcl")
}

inputs = merge(
local.tenant.inputs,
local.service.inputs
)
