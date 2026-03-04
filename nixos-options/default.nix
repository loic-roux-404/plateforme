{ lib, pkgs, config, ... }:

let 
  manifest = lib.types.submodule ({ ... }: {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to create this manifest file.";
      };

      targetDir = lib.mkOption {
        type = lib.types.nonEmptyStr;
        example = lib.literalExpression "manifest.yaml";
        default = "/var/lib/rancher/rke2/server/manifests";
        description = ''
          Name of the symlink (relative to {file}).
          Defaults to the attribute name.
        '';
      };

      content = lib.mkOption {
        type = lib.types.str;
        default = null;
        description = ''
          The source `.yaml` file.
        '';
      };
    };
  }
); in {
  options.paas = {

    certs = lib.mkOption {
      default = [
        ../nixos-darwin/pebble/cert.crt
      ];
      type = lib.types.listOf (lib.types.path);
      description = "Ca url to fetch and trust (need to be impure)";
    };

    dns.name = lib.mkOption {
      default = "kube.test";
      type = lib.types.str;
      description = "hostname for paas";
    };

    dns.dest-ips = lib.mkOption {
      default = [ "127.0.0.1" ];
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

    kube.config = lib.mkOption {
      type = lib.types.path;
      description = "Kubeconfig path";
      default = "/etc/rancher/rke2/rke2.yaml";
    };

    kube.disableServices = lib.mkOption {
      default = [];
      type = lib.types.listOf lib.types.str;
      description = "Disable k8s services eg: traefik,servicelb";
    };

    kube.serverExtraArgs = lib.mkOption {
      default = [ ];
      type = lib.types.listOf lib.types.str;
      description = "Extra arguments for k8s server (ex --flannel-backend=none --disable-network-policy)";
    };

    kube.token = lib.mkOption {
      type = lib.types.str;
      description = "K3s token";
      default = "";
    };

    kube.podCIDR = lib.mkOption {
      type = lib.types.str;
      description = "Pod CIDR";
      default = "10.42.0.0/16";
    };

    kube.podIpv6CIDR = lib.mkOption {
      type = lib.types.str;
      description = "Pod CIDR";
      default = "2001:cafe:42::/56";
    };

    kube.serviceCIDR = lib.mkOption {
      type = lib.types.str;
      description = "svc CIDR. Recommended : 10.43.0.0/16,2001:cafe:43::/112";
      default = "10.43.0.0/16";
    };

    kube.serviceIp = lib.mkOption {
      type = lib.types.str;
      description = "Service IP";
      default = "10.43.0.1";
    };

    kube.addr = lib.mkOption {
      default = "192.168.205.2";
      type = lib.types.str;
      description = "K8s service host";
    };

    kube.serviceHost = lib.mkOption {
      default = "127.0.0.1";
      type = lib.types.str;
      description = "K8s service host";
    };

    kube.servicePort = lib.mkOption {
      type = lib.types.str;
      description = "Service port";
      default = "6443";
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

    defaultKubeDistribConfigPath = lib.mkOption {
      type = lib.types.path;
      description = "Default config yaml";
    };

    manifests = lib.mkOption {
      type = lib.types.attrsOf manifest;
      description = "Manifests to apply";
      default = {};
    };
  };

  config = with config.paas; {
    paas.defaultKubeDistribConfigPath = pkgs.writeText "server-config.yaml" ''
      with-node-id: true
      advertise-address: ${kube.addr}
      node-external-ip: ${kube.addr}
      cluster-cidr: ${kube.podCIDR}
      service-cidr: ${kube.serviceCIDR}
      tls-san:
        - ${kube.serviceHost}
        - ${kube.serviceIp}
        - ${kube.addr}
        - ${config.networking.hostName or "localhost"}
      kube-apiserver-arg=authorization-mode: Node,RBAC
      kube-apiserver-arg=oidc-issuer-url: https://dex.${dns.name}
      kube-apiserver-arg=oidc-client-id: ${dex.dexClientId}
      kube-apiserver-arg=oidc-username-claim: email
      kube-apiserver-arg=oidc-groups-claim: groups
    '';

    paas.manifests."cert-manager.yaml" = {
      enable = true;
      content = ''
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
      '';
    };

    paas.manifests."local-path-storage.yaml" = {
      enable = true;
      content = builtins.readFile (pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.34/deploy/local-path-storage.yaml";
        hash = "sha256-+rjW6JM+RPivc5hgP7YxIuTqZJDwr4NUkQjWhkft2ek=";
      });
    };
  };
}
