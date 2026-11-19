include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${include.root.locals.base}//tf-root-apps${include.root.locals.suffix}"
}
