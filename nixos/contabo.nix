{ pkgs, ... }:
{

  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  swapDevices = [ ];

  security.sudo.wheelNeedsPassword = true;
  security.sudo = {
    enable = true;
    extraRules = [{
      commands = map (cmd: {
        command = cmd;
        options = [ "NOPASSWD" ];
      }) [
        "${pkgs.systemd}/bin/systemctl status"
        "${pkgs.systemd}/bin/systemctl show"
        "${pkgs.systemd}/bin/systemctl list-units"
        "${pkgs.systemd}/bin/systemctl list-machines"
        "${pkgs.systemd}/bin/systemctl list-jobs"
        "${pkgs.systemd}/bin/systemctl is-system-running"
        "${pkgs.systemd}/bin/journalctl"
        "${pkgs.k3s}/bin/kubectl get"
        "${pkgs.k3s}/bin/kubectl describe"
        "${pkgs.k3s}/bin/kubectl explain"
        "${pkgs.k3s}/bin/kubectl logs"
        "${pkgs.k3s}/bin/kubectl diff"
        "${pkgs.k3s}/bin/kubectl events"
        "${pkgs.k3s}/bin/kubectl wait"
        "${pkgs.k3s}/bin/kubectl api-resources"
        "${pkgs.k3s}/bin/kubectl version"
        "${pkgs.vim}/bin/vim"
        "${pkgs.less}/bin/less"
        "${pkgs.coreutils}/bin/tail"
        "${pkgs.coreutils}/bin/grep"
        "${pkgs.nettools}/bin/ifconfig"
        "${pkgs.iproute2}/bin/ip"
        "${pkgs.iptables}/bin/iptables"
      ];
      groups = [ "wheel" ];
    }];
  };

  k3s-paas.dns.name = "404-tools.xyz";
  k3s-paas.certs = [];
}
