{
  pkgs,
  config,
  lib,
  ...
}:

with config.paas;
{
  system.stateVersion = 5;

  environment.variables = {
    DOCKER_HOST = "tcp://127.0.0.1:2375";
  };

  environment.pathsToLink = [ "/share/fish" ];

  programs.zsh.enable = true;
  programs.zsh.shellInit = ''
    # Nix
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
      . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    # End Nix
  '';

  programs.fish.enable = true;
  programs.fish.shellInit = ''
    # Nix
    if test -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
      source '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
    end
    # End Nix
  '';

  environment.shells = with pkgs; [
    bashInteractive
    zsh
    fish
  ];
  environment.systemPackages = with pkgs; [
    cachix
  ];

  users.users.loic = {
    home = "/Users/loic";
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [ ];
  };

  users.groups = {
    docker.members = [ "loic" ];
    lxd.members = [ "loic" ];
    wheel.members = [ "loic" ];
  };

  system.primaryUser = "loic";

  services.dnsmasq = {
    enable = true;
    addresses = builtins.listToAttrs (
      builtins.map (value: {
        name = ".${dns.name}";
        inherit value;
      }) ([ kube.addr ])
    );
  };

  environment.etc."resolver/${dns.name}".text = "${lib.concatMapStrings (destIp: ''
    nameserver ${destIp}

  '') (dns.dest-ips ++ [ kube.addr ])}";

  launchd.daemons.libvirt = {
    path = [
      pkgs.gcc
      pkgs.qemu
      pkgs.dnsmasq
      pkgs.libvirt
    ];
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      ProgramArguments = [
        "${pkgs.libvirt}/bin/libvirtd"
        "-f"
        "/etc/libvirt/libvirtd.conf"
        "-v"
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
      ProgramArguments = [
        "${pkgs.libvirt}/bin/virtlogd"
        "-d"
      ];
      StandardOutPath = "/var/log/libvirt/virtlogd.log";
      StandardErrorPath = "/var/log/libvirt/virtlogd-error.log";
    };
  };

  launchd.daemons.minio = {
    script = ''
      sudo mkdir -p /var/lib/minio || true

      ${pkgs.minio}/bin/minio server /var/lib/minio \
        --address "127.0.0.1:9000" \
        --console-address "127.0.0.1:9001"
    '';
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;

      WorkingDirectory = "/tmp";
      StandardOutPath = "/var/log/minio.log";
      StandardErrorPath = "/var/log/minio-error.log";
      EnvironmentVariables = {
        MINIO_ROOT_USER = "minioadmin";
        MINIO_ROOT_PASSWORD = "minioadmin";
      };
    };
  };

  launchd.daemons.pebble = {
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      ProgramArguments = [
        "${pkgs.pebble}/bin/pebble"
        "-config"
        "/etc/pebble/config.json"
      ];
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
    trusted-users = [ "@admin" ];
    keep-derivations = true;
    keep-outputs = true;
    # https://github.com/NixOS/nix/issues/7273
    auto-optimise-store = false;
    extra-platforms = [ "x86_64-linux" ];
    allowed-uris = [ "raw.githubusercontent.com" ];
    experimental-features = "nix-command flakes";
  };

  nix.gc = {
    automatic = true;
    interval = {
      Weekday = 0;
      Hour = 0;
      Minute = 0;
    };
    options = "--delete-older-than 30d";
  };
  nix.linux-builder = {
    enable = true;
    maxJobs = 2;
    package = lib.mkDefault pkgs.darwin.linux-builder;
    ephemeral = lib.mkDefault false;
    config = (
      { lib, ... }:
      {
        virtualisation.docker.enable = true;
        virtualisation.docker.daemon.settings = {
          hosts = [ "tcp://0.0.0.0:2375" ];
        };
        networking.firewall.enable = lib.mkForce false;
        networking.firewall.allowedTCPPorts = [ 2375 ];
        virtualisation.forwardPorts = lib.mkForce [
          {
            from = "host";
            guest.port = 22;
            host.port = 31022;
          }
          {
            from = "host";
            guest.port = 2375;
            host.port = 2375;
          }
        ];
        security.sudo.wheelNeedsPassword = false;
        environment.systemPackages = [
          pkgs.htop
        ];
        users.users.builder.extraGroups = lib.mkForce [
          "docker"
          "wheel"
        ];
        users.users.builder.openssh.authorizedKeys.keys = [ user.key ];
      }
    );
  };

  nix.enable = true;
}
