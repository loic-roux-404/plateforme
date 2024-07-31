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

  system.stateVersion = "24.05";

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
      extraUpFlags = lib.mkDefault ["--ssh"];
      permitCertUid = user.name;
    };
    k3s = {
      enable = lib.mkDefault false;
      role = "server";
      extraFlags = lib.strings.concatStringsSep " " (
        map (service: "--disable=${service}") k3s.disableServices
        ++ k3s.serverExtraArgs
        ++ [
          "--flannel-backend=none"
          "--disable-network-policy"
          "--disable-kube-proxy"
          "--write-kubeconfig-mode=400"
        ]
      );
    };

    fail2ban.enable = true;
  };

  systemd.services.tailscaled-autoconnect = lib.mkIf (config.services.tailscale.authKeyFile != null &&
    config.services.tailscale.enable 
  ) {
    serviceConfig = {
      RemainAfterExit = true; # Ensures it's remains active after running.
    };
  };

  systemd.user.services.nixos-activation = {
    after = ["tailscaled.service" "tailscaled-autoconnect.service"];
  };

  system.activationScripts.checkTailscaleStatus = lib.mkIf (config.networking.hostName != "" &&
    config.services.tailscale.enable &&
    config.services.tailscale.authKeyFile != null
  ) { text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      ${pkgs.tailscale}/bin/tailscale ping -c 1 "${config.networking.hostName}" || \
        ${pkgs.systemd}/bin/systemctl restart tailscaled.service; \
        ${pkgs.systemd}/bin/systemctl restart tailscaled-autoconnect.service || true;
    ''; 
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${config.k3s-paas.user.name} = {
    xdg.enable = true;
    home.stateVersion = "24.05";
    home.sessionVariables = {
      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    };
    home.shellAliases = {
      kubectl = "sudo kubectl";
      helm = "sudo -E helm";
    };
    programs.bash = {
      enable = true;
      historyControl = [ "ignoredups" "ignorespace" ];
    };
  };

  system.activationScripts.k3sCerts.text = (pkgs.callPackage ./install-k3s-manifest.nix { 
    inherit pkgs;
    file = certManagerCrds;
  }).script;

  programs.vim.defaultEditor = true;
  environment = {
    shells = [ pkgs.bashInteractive ];
    variables = {
      PAGER = "less -FirSwX";
      SYSTEMD_EDITOR = "vim";
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
      cilium-cli
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
      checkReversePath = false;
      trustedInterfaces = [ "tailscale0" "cilium_host" "cilium_vxlan" "cilium_net" ];
      enable = true;
      allowedTCPPorts = lib.mkDefault [ 80 443 22 ];
      allowedUDPPorts = [ config.services.tailscale.port ];
    };
    nftables.enable = true;
    networkmanager.enable = false;
    usePredictableInterfaceNames = true;
  };

  boot.kernel.sysctl = {
    "net.ipv4.conf.lxc*.rp_filter" = 0;
    "net.ipv4.conf.cilium_*.rp_filter" = 0;
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
