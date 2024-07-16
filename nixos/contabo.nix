{ ... }:
{

  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  swapDevices = [ ];

  # TODO should move in sops template configurations
  k3s-paas.dns.name = "404-tools.xyz";
  k3s-paas.certs = [];
}
