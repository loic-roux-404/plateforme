{ lib, pkgs, config, ... }:

let 
  manifest = lib.types.submodule ({ ... }: {
    options = {
      targetDir = lib.mkOption {
        type = lib.types.nonEmptyStr;
        example = lib.literalExpression "manifest.yaml";
        default = "/var/lib/rancher/k3s/server/manifests";
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
      default = [ "127.0.0.1" "192.168.205.8" ];
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
      default = "/etc/rancher/k3s/k3s.yaml";
    };

    kube.disableServices = lib.mkOption {
      default = [ "traefik" "servicelb" "rke2-ingress-nginx" ];
      type = lib.types.listOf lib.types.str;
      description = "Disable k8s services eg: traefik,servicelb";
    };

    kube.serverExtraArgs = lib.mkOption {
      default = [ "--disable-kube-proxy" "--flannel-backend=none" "--disable-network-policy" ];
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

    kube.clusterDns = lib.mkOption {
      type = lib.types.str;
      description = "Cluster DNS";
      default = "10.43.0.10";
    };

    kube.serviceIp = lib.mkOption {
      type = lib.types.str;
      description = "Service IP";
      default = "10.43.0.1";
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

    cilium.version = lib.mkOption {
      type = lib.types.str;
      description = "Cilium version";
      default = "1.16.4";
    };

    cilium.values-source = lib.mkOption {
      type = lib.types.path;
      description = "Cilium values source";
      default = null;
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

    manifests = lib.mkOption {
      type = lib.types.attrsOf manifest;
      description = "Manifests to apply";
      default = {};
    };
  };

  config = with config.paas; {
    paas.defaultK3sConfigPath = pkgs.writeText "server-config.yaml" ''
      with-node-id: true
      advertise-address: "192.168.205.8"
      node-external-ip: "192.168.205.8"
      cluster-cidr: ${kube.podCIDR}
      service-cidr: ${kube.serviceCIDR}
      cluster-dns: ${kube.clusterDns}
      node-taint:
        - "CriticalAddonsOnly=true:NoExecute"
      tls-san:
        - ${kube.serviceHost}
        - ${kube.serviceIp}
        - 192.168.205.8
        - ${config.networking.hostName or "localhost"}
      kube-apiserver-arg=authorization-mode: Node,RBAC
      kube-apiserver-arg=oidc-issuer-url: https://dex.${dns.name}
      kube-apiserver-arg=oidc-client-id: ${dex.dexClientId}
      kube-apiserver-arg=oidc-username-claim: email
      kube-apiserver-arg=oidc-groups-claim: groups
    '';

    paas.manifests."cert-manager.yaml".content = ''
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

    paas.manifests."external-load-balancer-pool.yaml".content = ''
      apiVersion: cilium.io/v2alpha1
      kind: CiliumLoadBalancerIPPool
      metadata:
        name: cilium-lb-ipam-external
      spec:
        blocks:
          - start: 192.168.205.8
            stop: 192.168.205.8
        serviceSelector:
          matchLabels:
            "kube-paas/external": "true"
      '';

    paas.manifests."internal-load-balancer-pool.yaml".content = ''
      apiVersion: cilium.io/v2alpha1
      kind: CiliumLoadBalancerIPPool
      metadata:
        name: cilium-lb-ipam-internal
      spec:
        blocks:
          - cidr: 10.0.0.1/24
        serviceSelector:
          matchLabels:
            "kube-paas/internal": "true"
    '';

    paas.manifests."cilium-ingress-internal.yaml".content = ''
      apiVersion: v1
      kind: Service
      metadata:
        name: cilium-ingress-internal
        namespace: kube-system
        labels:
          "cilium.io/ingress": "true"
          "kube-paas/internal": "true"
      spec:
        type: LoadBalancer
        allocateLoadBalancerNodePorts: true
        externalTrafficPolicy: Cluster
        internalTrafficPolicy: Cluster
        sessionAffinity: None
        ipFamilyPolicy: SingleStack
        ipFamilies:
          - IPv4
        ports:
          - name: http
            port: 80
            targetPort: 80
            protocol: TCP
          - name: https
            port: 443
            targetPort: 443
            protocol: TCP
    '';

    paas.cilium.values-source = pkgs.writeText "cilium-values.yaml" ''
      kubeProxyReplacement: true
      k8sServiceHost: "192.168.205.8"
      k8sServicePort: "${kube.servicePort}"
      autoDirectNodeRoutes: true
      routingMode: native
      l7Proxy: false
      #encryption:
      #  enabled: true
      #  type: wireguard
      #  nodeEncryption: true
      #ipv6:
        #enabled: true
      ipv4NativeRoutingCIDR: "${kube.podCIDR}"
      #ipv6NativeRoutingCIDR: "${kube.podIpv6CIDR}"
      ipam:
        mode: kubernetes
        operator:
          clusterPoolIPv4PodCIDRList:
            - "${kube.podCIDR}"
          #clusterPoolIPv6PodCIDRList:
            #- "${kube.podIpv6CIDR}"
      bpf:
        masquerade: true
        lbExternalClusterIP: false
      l2announcements:
        enabled: true
      #loadBalancer:
      #  acceleration: native
      #  mode: hybrid
      operator:
        replicas: 1
        prometheus:
          enabled: true
      gatewayAPI:
        enabled: false
      ingressController:
        enabled: true
        default: true
        loadbalancerMode: dedicated
        service:
          name: cilium-ingress-external
          labels:
            kube-paas/external: "true"
      prometheus:
        enabled: true
      hubble:
        enabled: true
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
      '';
  };
}
