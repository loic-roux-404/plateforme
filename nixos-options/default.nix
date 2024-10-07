{ lib, pkgs, config, ... }:

{
  options.paas = {

    certs = lib.mkOption {
      default = [
        ../nixos-darwin/pebble/cert.crt
      ];
      type = lib.types.listOf (lib.types.path);
      description = "Ca url to fetch and trust (need to be impure)";
    };

    dns.name = lib.mkOption {
      default = "k3s.test";
      type = lib.types.str;
      description = "hostname for paas";
    };

    dns.dest-ips = lib.mkOption {
      default = [
        "127.0.0.1" "192.168.205.2" "192.168.205.3" "192.168.205.4" "192.168.205.5" 
        "192.168.205.6" "192.168.205.7" "192.168.205.8" "192.168.205.9"
      ];
      type = lib.types.listOf lib.types.str;
      description = "Target IP address for dns.name (only in local dev)";
    };

    user.name = lib.mkOption {
      default = "admin";
      type = lib.types.str;
      description = "User name";
    };

    user.defaultPassword = lib.mkOption {
      default = "$6$zizou$reVO3q7LFsUq.GT5P5pYFFcpxCo7eTRT5yJTD.gVoOy/FSzHEtXdofvZ7E04Rej.jiQHKaWJB0Qob5FHov1WU/";
      type = lib.types.str;
      description = "Default password for user";
    };

    user.key = lib.mkOption {
      default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC94/4uRn429xMGLFWZMyJWlhb5D0L3EoO8HxzN4q1ps loic@Windows-8-Phone.local";
      type = lib.types.str;
      description = "SSH public key for paas.";
    };

    k3s.disableServices = lib.mkOption {
      default = [ "traefik" "rke2-ingress-nginx" ];
      type = lib.types.listOf lib.types.str;
      description = "Disable k8s services eg: traefik,servicelb";
    };

    k3s.serverExtraArgs = lib.mkOption {
      default = [];
      type = lib.types.listOf lib.types.str;
      description = "Extra arguments for k8s server";
    };

    k3s.token = lib.mkOption {
      type = lib.types.str;
      description = "K3s token";
      default = "";
    };

    k3s.podCIDR = lib.mkOption {
      type = lib.types.str;
      description = "Pod CIDR";
      default = "10.100.0.0/16";
    };

    k3s.serviceCIDR = lib.mkOption {
      type = lib.types.str;
      description = "Pod CIDR";
      default = "10.110.0.0/16";
    };

    k3s.clusterDns = lib.mkOption {
      type = lib.types.str;
      description = "Cluster DNS";
      default = "10.110.0.10";
    };

    k3s.serviceIp = lib.mkOption {
      type = lib.types.str;
      description = "Service IP";
      default = "10.110.0.1";
    };

    k3s.servicePort = lib.mkOption {
      type = lib.types.str;
      description = "Service port";
      default = "6443";
    };

    cilium.version = lib.mkOption {
      type = lib.types.str;
      description = "Cilium version";
      default = "1.16.1";
    };

    dex.dexClientId = lib.mkOption {
      type = lib.types.str;
      description = "Client ID for Dex";
      default = "dex-paas-org-404";
    };

    cert-manager.version = lib.mkOption {
      type = lib.types.str;
      description = "Cert Manager version";
      default = "1.15.2";
    };

    defaultK3sConfigPath = lib.mkOption {
      type = lib.types.path;
      description = "Default config yaml";
    };

    certManagerConfigPath = lib.mkOption {
      type = lib.types.path;
      description = "Cert Manager config yaml";
    };

    ciliumConfigPath = lib.mkOption {
      type = lib.types.path;
      description = "Cilium config yaml";
    }; 
  };

  config = with config.paas; {
    paas.defaultK3sConfigPath = pkgs.writeText "server-config.yaml" ''
      with-node-id: true
      cluster-cidr: ${k3s.podCIDR}
      service-cidr: ${k3s.serviceCIDR}
      cluster-dns: ${k3s.clusterDns}
      tls-san:
        - localhost
        - 127.0.0.1
        - ${k3s.serviceIp}
        - ${config.networking.hostName}
      kube-apiserver-arg=authorization-mode: Node,RBAC
      kube-apiserver-arg=oidc-issuer-url: https://dex.${dns.name}
      kube-apiserver-arg=oidc-client-id: ${dex.dexClientId}
      kube-apiserver-arg=oidc-username-claim: email
      kube-apiserver-arg=oidc-groups-claim: groups
    '';

    paas.certManagerConfigPath = lib.mkDefault (pkgs.writeText "cert-manager.yaml" ''
      apiVersion: helm.cattle.io/v1
      kind: HelmChart
      metadata:
        name: cert-manager
        namespace: kube-system
      spec:
        name: cert-manager
        targetNamespace: cert-manager
        createNamespace: true
        repo: https://charts.jetstack.io
        chart: cert-manager
        version: ${cert-manager.version}
        backOffLimit: 200
        timeout: 180s
        valuesContent: |-
          crds:
            enabled: true
    '');

    paas.ciliumConfigPath = lib.mkDefault (pkgs.writeText "cilium.yaml" ''
      apiVersion: helm.cattle.io/v1
      kind: HelmChartConfig
      metadata:
        name: rke2-cilium
        namespace: kube-system
      spec:
        valuesContent: |-
          l2announcements:
            enabled: true
          ingressController:
            enabled: true
            default: true
          operator:
            replicas: 1
            prometheus:
              enabled: true
          hubble:
            relay:
              enabled: true
    '');
  };
}
