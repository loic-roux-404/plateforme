include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${include.root.locals.base}//tf-root-paas${include.root.locals.suffix}"
}
