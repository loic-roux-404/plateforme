{
  config,
  lib,
  pkgs,
  srvosPackages,
  oldLegacyPackages,
  ...
}:

with config.paas;

let
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
  boot.tmp.useTmpfs = true;
  boot.tmp.cleanOnBoot = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.loader.systemd-boot.consoleMode = "auto";

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = 1;

  swapDevices = [ ];
  zramSwap.algorithm  = "zstd";

  system.stateVersion = "24.05";

  time = {
    timeZone = lib.mkForce "Europe/Paris";
    hardwareClockInLocalTime = true;
  };

  i18n.defaultLocale = "en_US.UTF-8";

  boot.kernelModules = [ "br_netfilter" "ip_conntrack" "ip_vs" "ip_vs_rr" "ip_vs_wrr" "ip_vs_sh" "overlay" ];  

  networking = {
    useDHCP = true;
    useNetworkd = true;
    nftables.enable = true;
    firewall = {
      enable = lib.mkForce false;
    };
  };

  # deploy all netbird with nixos, configure dex idp with terraform network playbook
  # Make a service doing like tailscale autoconnect netbird join ? maybe not needed as we are the control server ?
  # Check cilium config
  # https://docs.netbird.io/how-to/routing-peers-and-kubernetes

  #services.netbird.enable = true;

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
    package = pkgs.rke2_latest;
    role = "server";
    cni = "cilium";
    extraFlags = map (service: "--disable=${service}") kube.disableServices
      ++ kube.serverExtraArgs;
    configPath = lib.mkDefault defaultK3sConfigPath;
  };

  systemd.tmpfiles.rules = builtins.attrValues (
    builtins.mapAttrs (name: manifest: 
    "C ${manifest.targetDir}/${name} 0640 - - - ${pkgs.writeText name manifest.content}") manifests
  );

  programs.vim.defaultEditor = true;
  environment = {
    shells = [ pkgs.bashInteractive ];
    variables = {
      PAGER = "less -FirSwX";
      SYSTEMD_EDITOR = "vim";
      KUBECONFIG = config.paas.kube.config;
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
      srvosPackages.kubectl
      kubernetes-helm
      oldLegacyPackages.waypoint
      cilium-cli
      hubble
      iptables
      tcpdump
      ngrep
    ];
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

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${config.paas.user.name} = {
    xdg.enable = true;
    home.stateVersion = "24.05";
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
      historyControl = [ "ignoredups" "ignorespace" ];
    };
  };

  security.sudo.configFile = ''
    Defaults  env_keep += "SYSTEMD_EDITOR"
  '';
  security.pki.certificateFiles = certs;
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
    }];
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
