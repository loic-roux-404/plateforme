{ config, ... } : 

with config.k3s-paas;

{
  imports = [ ./temporary-configuration.nix ];

  sops.validateSopsFiles = false;
  sops.defaultSopsFormat = "yaml";
  sops.defaultSopsFile = "/home/${user.name}/secrets.yaml";
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  sops.secrets.tailscale = {};
  sops.secrets.password = {
    neededForUsers = true;
  };

  services.tailscale.authKeyFile = config.sops.secrets.tailscale.path;
  services.tailscale.extraUpFlags = ["--ssh" "--hostname=${config.networking.hostName}"];

  users.users.${user.name}.hashedPasswordFile = config.sops.secrets.password.path;
}
