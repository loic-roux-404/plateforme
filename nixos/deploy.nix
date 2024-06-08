{ config, ... } : 

with config.k3s-paas;
with config.age;
{
  imports = [ ./secrets-install.nix ];

  services.tailscale.authKeyFile = "/home/${user.name}/.tailscale";
  k3s-paas.tailscale.enable = true;
  networking.firewall.allowedTCPPorts = [80 443];

  users.users.${user.name}.hashedPasswordFile = "/home/${user.name}/.password";
  environment.etc."hostname".source = "/home/${user.name}/hostname";
}
