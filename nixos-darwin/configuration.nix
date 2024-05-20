{ pkgs, lib, config, ... }:
{
  programs.fish.enable = true;
  programs.bash.enable = true;
  environment.systemPackages = [ pkgs.bashInteractive ];
  launchd.daemons.linux-builder = {
    serviceConfig = {
      StandardOutPath = "/var/log/darwin-builder.log";
      StandardErrorPath = "/var/log/darwin-builder.log";
    };
  };
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
    ./pebble/cert.pem
  ] ++ builtins.map (cert: builtins.fetchurl { inherit (cert) url sha256; }) config.k3s-paas.certs;
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
    trusted-users = [ "staff" "admin" "nixbld"];
    keep-derivations = true;
    keep-outputs = false;
    # https://github.com/NixOS/nix/issues/7273
    auto-optimise-store = false;
  };
  nix.gc = {
    automatic = true;
    interval = { Weekday = 0; Hour = 0; Minute = 0; };
    options = "--delete-older-than 30d";
  };
  nix.linux-builder.enable = true;
  nix.linux-builder.maxJobs = 8;
  nix.linux-builder.ephemeral = true;
  nix.linux-builder.config = ({ pkgs, ... }:
  {
    virtualisation.docker.enable = true;
    virtualisation.docker.daemon.settings = {
      hosts = [ "tcp://0.0.0.0:2375" ];
    };
    networking.firewall.enable = lib.mkForce false;
    virtualisation.forwardPorts = lib.mkForce [
      { from = "host"; guest.port = 22; host.port = 31022; }
      { from = "host"; guest.port = 2375; host.port = 2375; }
    ];
    security.sudo.wheelNeedsPassword = false;
    users.users.builder.extraGroups = lib.mkForce [ "docker" "wheel" ];
  });
  nix.configureBuildUsers = true;
  nix.distributedBuilds = true;
  services.nix-daemon.enable = true;
  nix.settings.experimental-features = "nix-command flakes";
}
