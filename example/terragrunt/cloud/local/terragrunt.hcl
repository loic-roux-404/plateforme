include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${include.root.locals.base}//tf-modules-cloud//libvirt/${include.root.locals.suffix}"
}
