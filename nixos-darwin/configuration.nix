{ pkgs,
  lib,
  config, 
  linux-builder-config ? ({ pkgs, ... }: {}),
  ... }:
{
  programs.fish.enable = true;
  programs.bash.enable = true;
  environment.systemPackages = [ pkgs.bashInteractive ];

  services.dnsmasq = {
    enable = true;
    addresses = {
      ".${config.k3s-paas.dns.name}" = config.k3s-paas.dns.dest-ip;
    };
  };
  launchd.daemons."libvirt" = {
    path = [ pkgs.gcc pkgs.qemu pkgs.dnsmasq pkgs.libvirt ];
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      ProgramArguments = [ 
        "${pkgs.libvirt}/bin/libvirtd" "-f" "/etc/libvirt/libvirtd.conf" "-v"
      ];
      StandardOutPath = "/var/log/libvirt/libvirt.log";
      StandardErrorPath = "/var/log/libvirt/libvirt-error.log";
    };
  };
  launchd.daemons."virtlogd" = {
    path = [ pkgs.libvirt ];
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      ProgramArguments = [ "${pkgs.libvirt}/bin/virtlogd" "-d" ];
      StandardOutPath = "/var/log/libvirt/virtlogd.log";
      StandardErrorPath = "/var/log/libvirt/virtlogd-error.log";
    };
  };
  launchd.daemons."pebble" = {
    path = [ pkgs.pebble ];
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      ProgramArguments = [ "${pkgs.pebble}/bin/pebble" "-config" "/etc/pebble/config.json" ];
      StandardOutPath = "/var/log/pebble.log";
      StandardErrorPath = "/var/log/pebble-error.log";
    };
  };
  environment.etc."libvirt/libvirtd.conf".text = ''
    mode = "direct"
    unix_sock_group = "staff"
    unix_sock_ro_perms = "0770"
    unix_sock_rw_perms = "0770"
    unix_sock_admin_perms = "0770"
    auth_unix_ro = "none"
    auth_unix_rw = "none"
    log_level = 1
    log_outputs="1:stderr"
  '';
  environment.etc."libvirt/qemu.conf".text = ''
    security_driver = "none"
    dynamic_ownership = 0
    remember_owner = 0
  '';
  security.pki.certificateFiles = [
    "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ./pebble/cert.pem
  ];
  environment.etc."pebble/config.json".text = builtins.toJSON {
    pebble = {
      listenAddress = "0.0.0.0:14000";
      managementListenAddress = "0.0.0.0:15000";
      certificate = pkgs.writeText "pebble-cert" (builtins.readFile ./pebble/cert.pem);
      privateKey = pkgs.writeText "pebble-key" (builtins.readFile ./pebble/key.pem);
      httpPort = 80;
      tlsPort = 443;
      ocspResponderURL = "";
      externalAccountBindingRequired = false;
    };
  };
  environment.etc."resolver/${config.k3s-paas.dns.name}".text = "nameserver ${config.k3s-paas.dns.dest-ip}";
  nix.settings = {
    trusted-users = [ "staff" "admin" "nixbld" "loic"];
    keep-derivations = true;
    keep-outputs = false;
    # https://github.com/NixOS/nix/issues/7273
    auto-optimise-store = false;
    system-features = [
      "nixos-test"
      "apple-virt"
    ];
  };
  nix.gc = {
    automatic = true;
    interval = { Weekday = 0; Hour = 0; Minute = 0; };
    options = "--delete-older-than 30d";
  };
  nix.linux-builder = {
    enable = true;
    maxJobs = 8;
    package = pkgs.darwin.linux-builder-x86_64;
    ephemeral = true;
    config = linux-builder-config;
  };
  nix.configureBuildUsers = true;
  services.nix-daemon.enable = true;
  nix.settings.experimental-features = "nix-command flakes";
}
