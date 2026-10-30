terraform {
  source = "../../..//modules/consumers"
}

locals {
  tenant = read_terragrunt_config("../local.hcl")
}

inputs = merge(
  local.tenant.inputs,
  {
    consumers = {
      tf-front-iti = {
        api_key    = "CLE-TF-ITI"
        acl_groups = ["front-iti", "front-forward"]
        referer    = "^https?://www\\.formation\\.local(/|$)"
      }
    }
  }
)
