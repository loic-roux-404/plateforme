{
  config,
  lib,
  pkgs,
  srvosPackages,
  legacyPackages,
  ...
}:

with config.paas;

let
  userSshConfig = {
    authorizedKeys = {
      keys = [ user.key ];
    };
  };
in
{

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
  boot.tmp.useTmpfs = true;
  boot.tmp.cleanOnBoot = true;
  # Pin to the 6.12 LTS kernel, known-good for the open_tree/move_mount file-bind path.
  boot.kernelPackages = pkgs.linuxPackages_6_12;
  boot.loader.systemd-boot.consoleMode = "auto";

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = 1;

  swapDevices = [ ];
  zramSwap.algorithm = "zstd";

  system.stateVersion = "25.11";

  time = {
    timeZone = lib.mkForce "Europe/Paris";
    hardwareClockInLocalTime = true;
  };

  i18n.defaultLocale = "en_US.UTF-8";

  boot.kernelModules = [
    "br_netfilter"
    "ip_conntrack"
    "ip_vs"
    "ip_vs_rr"
    "ip_vs_wrr"
    "ip_vs_sh"
    "overlay"
    "iscsi_tcp"
  ];

  networking = {
    useNetworkd = true;
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
      "2606:4700:4700::1111"
      "2606:4700:4700::1001"
      "8.8.8.8"
      "8.8.4.4"
      "001:4860:4860::8844"
      "2001:4860:4860::8888"
    ];
    interfaces.enp0s9.useDHCP = true;
    firewall = {
      allowedTCPPorts = [
        22
        80
        443
        2379 # etcd server client API
        2380 # etcd server peer API
        6443 # kube-apiserver
        9345 # RKE2 supervisor / node registration
        10250 # kubelet logs/metrics
      ];
      allowedUDPPorts = [
        8472 # Canal/Flannel VXLAN
      ];
      checkReversePath = "loose";
      trustedInterfaces = [
        "lxc+"
        "lxc*"
      ];
    };
  };

  services.openiscsi = {
    enable = true;
    name = "iqn.2026-04.com.open-iscsi:${config.networking.hostName}";
  };

  services.fail2ban.enable = true;

  programs.ssh.package = pkgs.openssh_hpn;
  services.openssh = {
    enable = true;
    settings = {
      GatewayPorts = "clientspecified";
      PasswordAuthentication = lib.mkForce false;
      StreamLocalBindUnlink = lib.mkForce "yes";
      PermitRootLogin = "no";
    };
  };

  services.rke2 = {
    enable = lib.mkDefault true;
    package = legacyPackages.rke2_latest;
    role = "server";
    cni = "canal";
    extraFlags = map (service: "--disable=${service}") kube.disableServices ++ kube.serverExtraArgs;
    configPath = lib.mkDefault defaultKubeDistribConfigPath;
  };

  # currently a bug in latest kernel versions 6.12-lts and 7
  systemd.services.rke2-server.environment.LIBMOUNT_FORCE_MOUNT2 = "always";

  systemd.tmpfiles.rules =
    (builtins.attrValues (
      builtins.mapAttrs (
        name: manifest: "C ${manifest.targetDir}/${name} 0640 - - - ${pkgs.writeText name manifest.content}"
      ) (lib.filterAttrs (n: v: v.enable) manifests)
    ))
    ++ [
      "L+ /usr/local/bin - - - - /run/current-system/sw/bin/"
    ];

  programs.vim.defaultEditor = true;
  environment = {
    shells = [ pkgs.bashInteractive ];
    variables = {
      PAGER = "less -FirSwX";
      SYSTEMD_EDITOR = "vim";
      KUBECONFIG = config.paas.kube.config;
      CRI_CONFIG_FILE = "/var/lib/rancher/rke2/agent/etc/crictl.yaml";
    };
    shellAliases = {
      k-ks = "kubectl -n kube-system";
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
      legacyPackages.kubectl
      srvosPackages.cri-tools
      kubernetes-helm
      iptables
      tcpdump
      ngrep
      openiscsi
    ];
  };

  users = {
    defaultUserShell = pkgs.bashInteractive;
    allowNoPasswordLogin = true;
    groups.readers = { };
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
        extraGroups = [
          "wheel"
          "networkmanager"
        ];
        openssh = userSshConfig;
      };
      root = {
        hashedPasswordFile = lib.mkDefault "${(pkgs.writeText "root-password" user.defaultPassword)}";
      };
    };
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${config.paas.user.name} = {
    home.homeDirectory = "/home/${config.paas.user.name}";
    xdg.enable = true;
    home.stateVersion = "25.05";
    home.sessionVariables = {
      KUBECONFIG = config.paas.kube.config;
    };
    home.shellAliases = {
      kubectl = "sudo -E kubectl";
      helm = "sudo -E helm";
      k-ks = "sudo -E kubectl -n kube-system";
    };
    programs.bash = {
      enable = true;
      historyControl = [
        "ignoredups"
        "ignorespace"
      ];
    };
  };

  security.sudo.configFile = ''
    Defaults  env_keep += "SYSTEMD_EDITOR"
  '';
  security.pki.certificateFiles = certs;
  security.sudo.wheelNeedsPassword = false;
  security.sudo = {
    enable = true;
    extraRules = [
      {
        commands =
          map
            (cmd: {
              command = cmd;
              options = [ "NOPASSWD" ];
            })
            [
              "${pkgs.systemd}/bin/systemctl status"
              "${pkgs.systemd}/bin/systemctl show"
              "${pkgs.systemd}/bin/systemctl list-units"
              "${pkgs.systemd}/bin/systemctl list-machines"
              "${pkgs.systemd}/bin/systemctl list-jobs"
              "${pkgs.systemd}/bin/systemctl is-system-running"
              "${pkgs.systemd}/bin/journalctl"
              "${pkgs.kubectl}/bin/kubectl get"
              "${pkgs.kubectl}/bin/kubectl describe"
              "${pkgs.kubectl}/bin/kubectl explain"
              "${pkgs.kubectl}/bin/kubectl logs"
              "${pkgs.kubectl}/bin/kubectl diff"
              "${pkgs.kubectl}/bin/kubectl events"
              "${pkgs.kubectl}/bin/kubectl wait"
              "${pkgs.kubectl}/bin/kubectl api-resources"
              "${pkgs.kubectl}/bin/kubectl version"
              "${pkgs.nettools}/bin/ifconfig"
              "${pkgs.iproute2}/bin/ip"
              "${pkgs.iptables}/bin/iptables"
            ];
        groups = [ "wheel" ];
      }
    ];
  };

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
