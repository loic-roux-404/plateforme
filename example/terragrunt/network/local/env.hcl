locals {
  env          = "local"
  dependencies = read_terragrunt_config(find_in_parent_folders("dependencies.hcl"))
  wrapper      = dirname(dirname(find_in_parent_folders("root.hcl")))
  secret_vars  = yamldecode(sops_decrypt_file("${local.wrapper}/local.yaml"))
  input_vars = {
    gandi_token = ""
    machine     = local.dependencies.dependency.cloud.outputs
    # host minio via the vmnet bridge gateway: reachable BOTH from terraform
    # (macOS) and from longhorn inside the VM (loopback would break the pod)
    object_storage = {
      access_key = "minioadmin"
      secret_key = "minioadmin"
      s3_url     = "http://192.168.2.1:9000"
      region     = "us-east-1"
    }
    # PLATEFORME_REF default = floating main (raw runs); `paas` exports the locked ref.
    # NIX_FLAKE_ATTR: deploy-bootstrap (local reset phase 1: no apiserver oidc —
    # dex does not exist yet) → deploy (steady state). `paas reset` drives it.
    nix_flake          = "${get_env("PLATEFORME_REF", "github:loic-roux-404/plateforme/main")}#${get_env("NIX_FLAKE_ATTR", "deploy")}"
    nix_flake_reset    = "${get_env("PLATEFORME_REF", "github:loic-roux-404/plateforme/main")}#initial"
    additional_domains = local.secret_vars.additional_domains
  }
}
