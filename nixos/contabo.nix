{ config, lib, ... }:
{

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  swapDevices = [ ];

  paas.certs = [ ];

  # Match whatever ethernet device the cloud hypervisor provides (ens18, ens19, ...)
  # and configure it via DHCP. This is robust against PCI-slot reordering.
  systemd.network.networks."10-wan" = {
    matchConfig.Type = "ether";
    networkConfig.DHCP = "yes";
  };
}
