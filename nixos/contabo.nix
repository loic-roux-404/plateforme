{ lib, ... }:
{
  # boot.loader.grub = {
  #   efiSupport = true;
  #   efiInstallAsRemovable = true;
  #   device = "nodev";
  # };

  boot.initrd.kernelModules = lib.mkForce ["dm-snapshot"];
  k3s-paas.dns.name = "404-tools.xyz";
  k3s-paas.certs = [];
}
