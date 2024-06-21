{ config, pkgs, ... } : 

with config.k3s-paas;
{
  sops.validateSopsFiles = false;
  sops.defaultSopsFormat = "yaml";
  sops.defaultSopsFile = "/home/${user.name}/secrets.yaml";
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  sops.secrets.tailscale = {};
  sops.secrets.hostname = {};
  sops.secrets.password = {
    neededForUsers = true;
  };

  services.tailscale.authKeyFile = config.sops.secrets.tailscale.path;

  users.users.${user.name}.hashedPasswordFile = config.sops.secrets.password.path;

  environment.etc."hostname".source = config.sops.secrets.hostname.path;
  system.activationScripts.tailscale.text = ''
    ${pkgs.systemd}/bin/hostnamectl set-hostname --transient $(cat /etc/hostname)
  '';
}
