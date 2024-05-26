{ lib, ... }:
{

  boot.loader.grub.device = lib.mkForce "/dev/sda";

  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  swapDevices = [ ];

  k3s-paas.dns.name = "404-tools.xyz";
  k3s-paas.certs = [];
  
  system.autoUpgrade.flake = "github:loic-roux-404/k3s-paas#nixosConfigurations.${pkgs.system}.default";
}
 