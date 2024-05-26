{
  config,
  lib,
  pkgs,
  stableLegacyPackages,
  modulesPath,
  ...
}: 

let
  certs = builtins.map (cert: builtins.fetchurl { inherit (cert) url sha256; }) config.k3s-paas.certs;
  certManagerCrds = builtins.fetchurl {
    url = "https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.crds.yaml";
    sha256 = "060bn3gvrr5jphaig1g195prip5rn0x1s7qrp09q47719fgc6636";
  };
  manifests = builtins.filter (d: d != "") [certManagerCrds];
in {
  system.build.qcow = lib.mkForce (import "${toString modulesPath}/../lib/make-disk-image.nix" {
    inherit lib config pkgs;
    diskSize = "auto";
    format = "qcow2-compressed";
    partitionTableType = "hybrid";
  });

  console = {
    earlySetup = true;
    keyMap = "fr";
  };

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
    };
    k3s = {
      enable = true;
      role = "server";
      extraFlags = with config.k3s-paas; toString [
        (if k3s.disableServices != "" then "--disable=${k3s.disableServices}" else "")
       ];
    };

    fail2ban.enable = true;
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${config.k3s-paas.user.name} = {
    xdg.enable = true;
    home.stateVersion = "23.05";
    home.sessionVariables = {
      EDITOR = "vim";
      PAGER = "less -FirSwX";
    };
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
      stableLegacyPackages.waypoint
      tailscale
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  users = {
    defaultUserShell = pkgs.bashInteractive;
    allowNoPasswordLogin = true;
    users = {
      ${config.k3s-paas.user.name} = {
        password = config.k3s-paas.user.password;
        isNormalUser = true;
        extraGroups = [ "wheel" "networkmanager" ];
        openssh = {
          authorizedKeys = {
            keys = [
              config.k3s-paas.user.key
            ];
          };
        };
      };
    };
  };

  networking = {
    hostName = "k3s-paas";
    useNetworkd = true;
    useDHCP = true;
    firewall = {
      enable = true;
      allowedTCPPorts = lib.mkForce [80 443 22 6443];
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
