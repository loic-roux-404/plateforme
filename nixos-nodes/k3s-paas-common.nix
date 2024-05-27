{ lib, config, modulesPath, ... }:
{
  imports = [ 
    "${toString modulesPath}/profiles/qemu-guest.nix"
  ];

  deployment = {
    targetHost = config.k3s-paas.dns.name;
    buildOnTarget = true;
  };

  networking.firewall.allowedTCPPorts = lib.mkForce [80 443 22 6443];
}
