locals {
  env          = "local"
  dependencies = read_terragrunt_config(find_in_parent_folders("dependencies.hcl"))
  wrapper      = dirname(dirname(find_in_parent_folders("root.hcl")))
  secret_vars  = yamldecode(sops_decrypt_file("${local.wrapper}/local.yaml"))
  input_vars = merge(
    local.dependencies.dependency.network.outputs,
    local.dependencies.dependency.paas.outputs,
    local.secret_vars,
    {
      storage_class            = "longhorn"
      smtp_relay_storage_class = "longhorn"

      # required tf-root-apps inputs the local wrapper secret set may not
      # carry: fall back to local-only placeholders (relay auth unused locally,
      # public chart registries need no ghcr auth)
      smtp_main_username = try(local.secret_vars.smtp_main_username, "local")
      smtp_main_password = try(local.secret_vars.smtp_main_password, "local")
      github_username    = try(local.secret_vars.github_username, "local")
      github_token       = try(local.secret_vars.github_token, "")

      # PARTIAL STACK: enable exactly ONE app (plus the db/services it needs)
      # per test run — the VM has ~6 GiB RAM and a 24 GiB disk. Flip the flag
      # for the app under test, apply, verify, then destroy before the next.
      #   n8n      -> self-contained (postgres + valkey)
      #   mail     -> relay only; supabase needs it, so supabase implies it
      #   supabase -> supabase + mail relay
      #   appsmith -> self-contained (mongodb + postgres + valkey)
      enable_n8n        = false
      enable_mail_relay = false
      enable_supabase   = false
      enable_appsmith   = true

      # single-node VM: a 3-node MongoDB replicaset never converges here
      appsmith_mongodb_replica_count = 1
    },
  )
}
