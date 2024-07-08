include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "../tg-envcommon/env.hcl"
  expose = true
}

terraform {
  source = "${include.envcommon.locals.base_source_url}"
}
