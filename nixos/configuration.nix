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
  manifests = [certManagerCrds];
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
      extraUpFlags = ["--ssh"];
      extraDaemonFlags = tailscale.baseDaemonExtraArgs;
      permitCertUid = user.name;
    };
    k3s = {
      enable = true;
      role = "server";
      extraFlags = lib.strings.concatStringsSep " " ([
          (if k3s.disableServices != "" then "--disable=${k3s.disableServices}" else "")
        ] ++ (if dex.dexClientId != "" then [
          "--kube-apiserver-arg authorization-mode=Node,RBAC"
          "--kube-apiserver-arg oidc-issuer-url=https://dex.${dns.name}"
          "--kube-apiserver-arg oidc-client-id=${dex.dexClientId}"
          "--kube-apiserver-arg oidc-username-claim=email"
          "--kube-apiserver-arg oidc-groups-claim=groups"
        ] else [])
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

  system.activationScripts.k3s-certs.text = ''
    mkdir -p /var/lib/rancher/k3s/server/manifests
  '' + lib.strings.concatMapStrings 
    (drv: "cp -fp ${drv} /var/lib/rancher/k3s/server/manifests;") manifests;

  environment = {
    shells = [ pkgs.bashInteractive ];
    variables = {
      EDITOR = "vim";
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

  security.sudo.wheelNeedsPassword = false;

  users = {
    defaultUserShell = pkgs.bashInteractive;
    allowNoPasswordLogin = true;
    users = {
      ${user.name} = {
        hashedPasswordFile = lib.mkDefault "${(pkgs.writeText "password" user.defaultPassword)}";
        isNormalUser = true;
        extraGroups = [ "wheel" "networkmanager" ];
        openssh = {
          authorizedKeys = {
            keys = [ user.key ];
          };
        };
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

  systemd.network = {
    enable = lib.mkForce true;
    wait-online.anyInterface = true;
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
