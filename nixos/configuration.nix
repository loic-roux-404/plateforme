{
  config,
  lib,
  pkgs,
  ...
}: 

let
  dex_hostname = "${config.k3s-paas.dex.http_scheme}://dex.${config.k3s-paas.dns.name}";
  k3sTokenFile = pkgs.writeText "token" config.k3s-paas.k3s.token;
  letsEncryptCa = with config.k3s-paas.letsencrypt; if crt != "" then [crt] else [];
  certManagerCrds = builtins.fetchurl {
    url = "https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.crds.yaml";
    sha256 = "060bn3gvrr5jphaig1g195prip5rn0x1s7qrp09q47719fgc6636";
  };
  manifests = builtins.filter (d: d != "") [certManagerCrds];
in {
  imports = [ ./k3s-paas.nix ];

  console = {
    earlySetup = true;
    keyMap = "fr";
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;
  fileSystems."/".autoResize = true;
  fileSystems."/boot" =
    { device = "/dev/disk/by-label/boot";
      fsType = "vfat";
    };

  boot.loader.systemd-boot.consoleMode = "auto";

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
    };
    k3s = {
      enable = true;
      role = "server";
      tokenFile = k3sTokenFile;
      extraFlags = with config.k3s-paas; toString [
        "--kube-apiserver-arg authorization-mode=Node,RBAC"
        "--kube-apiserver-arg oidc-issuer-url=${dex_hostname}"
        "--kube-apiserver-arg oidc-client-id=${dex.dex_client_id}"
        "--kube-apiserver-arg oidc-username-claim=email"
        "--kube-apiserver-arg oidc-groups-claim=groups"
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
    home.file.".bashrc".source = lib.mkForce ./bashrc;
    home.file.".inputrc".source = ./inputrc;
    home.sessionVariables = {
      EDITOR = "vim";
      PAGER = "less -FirSwX";
    };
    programs.bash = {
      enable = true;
      historyControl = [ "ignoredups" "ignorespace" ];
      initExtra = "/home/${config.k3s-paas.user.name}/bashrc";
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
      waypoint
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
    useDHCP = false;
    firewall = {
      enable = true;
      allowedTCPPorts = lib.mkForce [80 443 22 6443 32701 9701];
    };
    nftables.enable = true;
    networkmanager.enable = true;
    usePredictableInterfaceNames = true;
  };

  systemd.network = {
    enable = true;
    wait-online.anyInterface = true;
  };

  security.pki.certificateFiles = letsEncryptCa;

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
