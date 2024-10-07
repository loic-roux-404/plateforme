{ 
  pkgs,
  config,
  lib,
  ... 
}:

with config.paas;

{
  programs.fish.enable = true;
  programs.bash.enable = true;
  programs.direnv.enable = true;

  services.dnsmasq = {
    enable = true;
    addresses = builtins.listToAttrs (builtins.map(value: {
      name = ".${dns.name}"; inherit value; 
    }) dns.dest-ips);
  };

  environment.etc."resolver/${dns.name}".text = "${lib.concatMapStrings (destIp: ''
    nameserver ${destIp}

  '') dns.dest-ips}";

  launchd.daemons.libvirt = {
    path = [ pkgs.gcc pkgs.qemu pkgs.dnsmasq pkgs.libvirt ];
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      ProgramArguments = [ 
        "${pkgs.libvirt}/bin/libvirtd" "-f" "/etc/libvirt/libvirtd.conf" "-v"
      ];
      WorkingDirectory = "/var/lib/libvirt";
      StandardOutPath = "/var/log/libvirt/libvirt.log";
      StandardErrorPath = "/var/log/libvirt/libvirt-error.log";
    };
  };
  launchd.daemons.virtlogd = {
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      WorkingDirectory = "/var/lib/libvirt";
      ProgramArguments = [ "${pkgs.libvirt}/bin/virtlogd" "-d" ];
      StandardOutPath = "/var/log/libvirt/virtlogd.log";
      StandardErrorPath = "/var/log/libvirt/virtlogd-error.log";
    };
  };
  launchd.daemons.pebble = {
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      ProgramArguments = [ "${pkgs.pebble}/bin/pebble" "-config" "/etc/pebble/config.json" ];
      WorkingDirectory = "/tmp";
      StandardOutPath = "/var/log/pebble.log";
      StandardErrorPath = "/var/log/pebble-error.log";
    };
  };

  system.activationScripts.importPebbleCert.text = ''
    curl -k https://localhost:15000/intermediates/0 > /tmp/pebble-ca.pem;
    sudo security add-trusted-cert -d -r trustAsRoot -k /Library/Keychains/System.keychain /tmp/pebble-ca.pem;
  '';

  environment.etc."libvirt/libvirtd.conf".text = ''
    mode = "direct"
    unix_sock_group = "staff"
    unix_sock_ro_perms = "0770"
    unix_sock_rw_perms = "0770"
    unix_sock_admin_perms = "0770"
    auth_unix_ro = "none"
    auth_unix_rw = "none"
    log_level = 3
    log_outputs="3:stderr"
  '';
  environment.etc."libvirt/qemu.conf".text = ''
    security_driver = "none"
    dynamic_ownership = 0
    remember_owner = 0
  '';
  security.pki.installCACerts = true;
  environment.etc."pebble/config.json".text = builtins.toJSON {
    pebble = {
      listenAddress = "0.0.0.0:14000";
      managementListenAddress = "0.0.0.0:15000";
      certificate = pkgs.writeText "cert" (builtins.readFile ./pebble/cert.crt);
      privateKey = pkgs.writeText "key" (builtins.readFile ./pebble/cert.key);
      httpPort = 80;
      tlsPort = 443;
      ocspResponderURL = "";
      externalAccountBindingRequired = false;
    };
  };
  nix.settings = {
    trusted-users = [ "staff" "admin" "nixbld" ];
    keep-derivations = true;
    keep-outputs = false;
    # https://github.com/NixOS/nix/issues/7273
    auto-optimise-store = false;
    extra-platforms = [ "x86_64-linux" ];
  };
  nix.gc = {
    automatic = true;
    interval = { Weekday = 0; Hour = 0; Minute = 0; };
    options = "--delete-older-than 30d";
  };
  nix.linux-builder = {
    enable = true;
    maxJobs = 8;
    package = lib.mkDefault pkgs.darwin.linux-builder;
    ephemeral = lib.mkDefault true;
  };
  nix.configureBuildUsers = true;
  services.nix-daemon.enable = true;
  nix.settings.experimental-features = "nix-command flakes";
}
