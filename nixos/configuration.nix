{
  config,
  lib,
  pkgs,
  oldLegacyPackages,
  ...
}:

with config.k3s-paas;

let
  certs = [ ../nixos-darwin/pebble/cert.crt ];
  certManagerCrds = builtins.fetchurl {
    url = "https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.crds.yaml";
    sha256 = "060bn3gvrr5jphaig1g195prip5rn0x1s7qrp09q47719fgc6636";
  };
  userSshConfig = {
    authorizedKeys = {
      keys = [ user.key ];
    };
  };
in {

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    autoResize = true;
    fsType = "ext4";
  };

  console = {
    earlySetup = true;
    keyMap = "fr";
  };

  boot.growPartition = lib.mkDefault true;
  boot.loader.grub.device = lib.mkForce "/dev/sda";
  boot.tmp.cleanOnBoot = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.loader.systemd-boot.consoleMode = "auto";

  zramSwap.algorithm  = "zstd";

  system.stateVersion = "23.05";

  time = {
    timeZone = lib.mkForce "Europe/Paris";
  };

  i18n.defaultLocale = "en_US.UTF-8";

  programs.ssh.package = pkgs.openssh_hpn;

  services = {
    openssh = {
      enable = true;
      settings = {
        # Allow forwarding ports to everywhere
        GatewayPorts = "clientspecified";
        PasswordAuthentication = lib.mkForce false;
        StreamLocalBindUnlink = lib.mkForce "yes";
        PermitRootLogin = "no";
      };
    };
    tailscale = {
      enable = true;
      openFirewall = true;
      extraUpFlags = lib.mkDefault ["--ssh"];
      permitCertUid = user.name;
    };
    k3s = {
      enable = true;
      role = "server";
      extraFlags = lib.strings.concatStringsSep " " (
        map (service: "--disable=${service}") k3s.disableServices
        ++ k3s.serverExtraArgs
      );
    };

    fail2ban.enable = true;
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${config.k3s-paas.user.name} = {
    xdg.enable = true;
    home.stateVersion = "23.11";
    programs.bash = {
      enable = true;
      historyControl = [ "ignoredups" "ignorespace" ];
    };
  };

  system.activationScripts.k3sCerts.text = (pkgs.callPackage ./install-k3s-manifest.nix { 
    inherit pkgs;
    manifest = {
      file = certManagerCrds;
      toWait = "crd/certificates.cert-manager.io";
      namespace = "";
      condition = "condition=established";
    };
  }).script;

  programs.vim.defaultEditor = true;
  environment = {
    shells = [ pkgs.bashInteractive ];
    variables = {
      PAGER = "less -FirSwX";
    };
    systemPackages = with pkgs; [
      glibcLocales
      systemd
      coreutils
      gawk
      bashInteractive
      vim
      gitMinimal
      openssh_hpn
      btop
      curl
      dnsutils
      jq
      wget
      k3s
      kubectl
      kubernetes-helm
      oldLegacyPackages.waypoint
      tailscale
    ];
  };

  security.sudo.configFile = ''
    Defaults  env_keep += "SYSTEMD_EDITOR"
  '';
  security.sudo.wheelNeedsPassword = false;
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
        "${pkgs.nettools}/bin/ifconfig"
        "${pkgs.iproute2}/bin/ip"
        "${pkgs.iptables}/bin/iptables"
      ];
      groups = [ "reader" ];
    }];
  };

  users = {
    defaultUserShell = pkgs.bashInteractive;
    allowNoPasswordLogin = true;
    groups.readers = {};
    users = {
      reader = {
        hashedPasswordFile = lib.mkDefault "${(pkgs.writeText "password" user.defaultPassword)}";
        isNormalUser = true;
        extraGroups = [ "readers" ];
        openssh = userSshConfig;
      };
      ${user.name} = {
        hashedPasswordFile = lib.mkDefault "${(pkgs.writeText "password" user.defaultPassword)}";
        isNormalUser = true;
        extraGroups = [ "wheel" "networkmanager" ];
        openssh = userSshConfig;
      };
      root = {
        hashedPasswordFile = lib.mkDefault "${(pkgs.writeText "root-password" user.defaultPassword)}";
      };
    };
  };

  networking = {
    useNetworkd = true;
    useDHCP = true;
    firewall = {
      trustedInterfaces = [ "tailscale0" "cni0" ];
      enable = true;
      allowedTCPPorts = lib.mkDefault [80 443 22 6443];
      allowedUDPPorts = [ config.services.tailscale.port ];
    };
    nftables.enable = true;
    networkmanager.enable = false;
    usePredictableInterfaceNames = true;
  };

  security.pki.certificateFiles = certs;

  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnsupportedSystem = true;
    };
  };

  nix = {
    optimise = {
      automatic = true;
    };

    settings.trusted-users = [ user.name ];
    settings.auto-optimise-store = true;

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
  };
}
