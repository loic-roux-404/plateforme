{
  config,
  lib,
  pkgs,
  oldLegacyPackages,
  ...
}:

with config.k3s-paas;

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

  swapDevices = [ ];
  zramSwap.algorithm  = "zstd";

  system.stateVersion = "24.05";

  time = {
    timeZone = lib.mkForce "Europe/Paris";
    hardwareClockInLocalTime = true;
  };

  i18n.defaultLocale = "en_US.UTF-8";

  networking = {
    enableIPv6 = true;
    useDHCP = true;
    useNetworkd = true;
    nftables.enable = true;
    nftables.flushRuleset  = true;
    firewall = {
      trustedInterfaces = [ "tailscale0" ];
      allowedTCPPorts = lib.mkDefault [ 80 443 22 ];
      allowedUDPPorts = [ config.services.tailscale.port ];
    };
  };

  programs.ssh.package = pkgs.openssh_hpn;
  services.openssh = {
    enable = true;
    settings = {
      # Allow forwarding ports to everywhere
      GatewayPorts = "clientspecified";
      PasswordAuthentication = lib.mkForce false;
      StreamLocalBindUnlink = lib.mkForce "yes";
      PermitRootLogin = "no";
    };
  };

  services.tailscale = {
    enable = true;
    extraUpFlags = lib.mkDefault ["--ssh"];
    permitCertUid = user.name;
    useRoutingFeatures = "both";
  };

  systemd.services.tailscaled-autoconnect = lib.mkIf (config.services.tailscale.authKeyFile != null &&
    config.services.tailscale.enable 
  ) {
    serviceConfig = {
      RemainAfterExit = true;
    };
  };

  systemd.user.services.nixos-activation = {
    after = ["tailscaled.service" "tailscaled-autoconnect.service"];
  };

  system.userActivationScripts.checkTailscaleStatus = lib.mkIf (config.networking.hostName != "" &&
    config.services.tailscale.enable &&
    config.services.tailscale.authKeyFile != null
  ) { text = ''
      #!/usr/bin/env bash

      ${pkgs.tailscale}/bin/tailscale ping -c 1 "${config.networking.hostName}" || \
        ${pkgs.systemd}/bin/systemctl restart tailscaled-autoconnect.service;
    ''; 
  };

  systemd.services.k3s.serviceConfig.Environment = "PATH=${pkgs.tailscale}/bin:${pkgs.coreutils}/bin";
  services.k3s = {
    enable = lib.mkDefault true;
    role = "server";
    extraFlags = lib.strings.concatStringsSep " " (
      map (service: "--disable=${service}") k3s.disableServices
      ++ k3s.serverExtraArgs
      ++ [
        "--flannel-backend=none"
        "--disable-kube-proxy"
        "--disable-network-policy"
        "--egress-selector-mode=disabled"
      ]
    );
    configPath = lib.mkDefault defaultK3sConfigPath;
    manifests.certManager.content = {
      apiVersion = "helm.cattle.io/v1";
      kind = "HelmChart";
      metadata = {
        name = "cilium";
        namespace = "kube-system";
      };
      spec = {
        name = "cert-manager";
        namespace = "cert-manager";
        createNamespace = true;
        repository = "https://charts.jetstack.io";
        chart = "cert-manager";
        version = cert-manager.version;
        wait = true;
        cleanup_on_fail = true;
        waitForJobs = true;
        timeout = 120;
        valuesContent = ''
          crds:
            enabled = true
        '';
      };
    };
    manifests.cilium.content = {
      apiVersion = "helm.cattle.io/v1";
      kind = "HelmChart";
      metadata = {
        name = "cilium";
        namespace = "kube-system";
      };
      spec = {
        name     = "cilium";
        namespace        = "kube-system";
        repository       = "https://helm.cilium.io";
        chart            = "cilium";
        wait = true;
        cleanup_on_fail = true;
        version          = cilium.version;
        valuesContent = ''
          l2announcements:
            enabled: true

          kubeProxyReplacement: true

          bpf:
            masquerade: true
            lbExternalClusterIP: false

          gatewayAPI:
            enabled: false

          routingMode: tunnel

          tunnelProtocol: vxlan

          ingressController:
            enabled: true
            default: true
            loadbalancerMode: dedicated
            service:
              name: cilium-ingress-external
              labels:
                k3s-paas/internal: "true"

          prometheus:
            enabled: true
            serviceMonitor:
              enabled: true

          operator:
            replicas: 1
            prometheus:
              enabled: true

          hubble:
            relay:
              enabled: true
            metrics:
              enabled:
                - dns
                - drop
                - tcp
                - flow
                - port-distribution
                - icmp
                - httpV2:exemplars=true;labelsContext=source_ip,source_namespace,source_workload,destination_ip,destination_namespace,destination_workload,traffic_direction
              enableOpenMetrics: true

          ipam:
            operator:
              clusterPoolIPv4PodCIDRList:
                - "${k3s.podCIDR}"
        '' + (if k3s.serviceHost != "" then ''
          k8sServiceHost: "${k3s.serviceHost}"
          k8sServicePort: "${k3s.servicePort}"
        '' else "");
      };
    };
  };

  services.fail2ban.enable = true;

  security.pki.certificateFiles = certs;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${config.k3s-paas.user.name} = {
    xdg.enable = true;
    home.stateVersion = "24.05";
    home.sessionVariables = {
      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
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
      iptables
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
