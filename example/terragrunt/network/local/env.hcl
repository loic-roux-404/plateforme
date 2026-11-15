locals {
  env          = "local"
  dependencies = read_terragrunt_config(find_in_parent_folders("dependencies.hcl"))
  wrapper      = dirname(dirname(find_in_parent_folders("root.hcl")))
  secret_vars  = yamldecode(sops_decrypt_file("${local.wrapper}/local.yaml"))
  input_vars = {
    gandi_token        = ""
    machine            = local.dependencies.dependency.cloud.outputs
    # contabo-only output (minio/S3); the libvirt cloud module does not emit it
    object_storage     = try(local.dependencies.dependency.cloud.outputs.object_storage, null)
    # PLATEFORME_REF default = floating main (raw runs); `paas` exports the locked ref
    nix_flake          = "${get_env("PLATEFORME_REF", "github:loic-roux-404/plateforme/main")}#deploy"
    nix_flake_reset    = "${get_env("PLATEFORME_REF", "github:loic-roux-404/plateforme/main")}#initial"
    additional_domains = local.secret_vars.additional_domains
  }
}
