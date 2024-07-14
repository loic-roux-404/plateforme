variable "dex_client_id" {
  type      = string
  sensitive = true
  default   = "dex-k3s-paas"
}

variable "node_ip" {
  type = string
}

variable "node_id" {
  type = string
}

variable "config" {
  type    = map(string)
  default = {}
}

variable "k3s_server_addr" {
  type    = string
  default = null
}

variable "ssh_connection" {
  type = object({
    public_key  = string
    private_key = string
    user        = string
  })
  sensitive = true
}

variable "nix_ssh_options" {
  type    = string
  default = ""
}

variable "nix_rebuild_arguments" {
  type    = list(string)
  default = ["--use-remote-sudo"]
}

variable "nixos_transient_secrets" {
  type    = map(string)
  default = {}
  sensitive = true
}

variable "nix_flake" {
  type = string

  nullable = false

  default = ".#deploy"

  description = <<-END
    Flake URI for the NixOS configuration to deploy

    The flake URI needs to be suitable for `nixos-rebuild`, meaning that you
    should not include `nixosConfigurations` in the attribute path of the flake
    URI.  For example, if your NixOS configuration were actually stored at
    `.#nixosConfigurations.machine` within your flake then the flake URI that
    `nixos-rebuild` would expect is actually `.#machine`.
    END

  validation {
    condition = length(split("#", var.nix_flake)) == 2

    error_message = "Invalid flake URI"
  }

  validation {
    condition = length(split("#", var.nix_flake)) == 2 ? split("#", var.nix_flake)[1] != "" : true

    # Note that nixos-rebuild supports empty attribute paths:
    #
    # https://github.com/NixOS/nixpkgs/blob/13645205311aa81dbc7c5adeee0382e38e52ee7c/pkgs/os-specific/linux/nixos-rebuild/nixos-rebuild.sh#L362-L367
    #
    # … but does so by attempting to guess the attribute path from the hostname.
    # We could in theory attempt to match this behavior in terraform, but it's
    # simpler to disallow this and instead require the user to specify a
    # non-empty attribute path.
    error_message = "Empty flake attribute paths not supported"
  }
}
