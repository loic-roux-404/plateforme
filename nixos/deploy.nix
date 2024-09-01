{ config,  ... } : 

with config.k3s-paas;
{
  networking.hostName = "localhost-0";
  sops.validateSopsFiles = false;
  sops.defaultSopsFormat = "yaml";
  sops.defaultSopsFile = "/home/${user.name}/secrets.yaml";
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" "${config.sops.secrets.nodePrivateKey.path}" ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.tailscale.authKeyFile = config.sops.secrets.tailscaleNodeKey.path;
  services.tailscale.extraUpFlags = [
    "--ssh" "--hostname=${config.networking.hostName}" 
  ];

  services.openssh.hostKeys = [
    {
      path = "${config.sops.secrets.nodePrivateKey.path}";
      type = "ed25519";
    }
    {
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
  ];

  sops.secrets.nodeIp = {};
  sops.secrets.internalNodeIp = {};
  sops.secrets.nodePrivateKey = {};
  sops.secrets.tailscaleNodeKey = {};
  sops.secrets.paasDomain = {};
  sops.secrets.tailscaleDomain = {};
  sops.secrets.password = { neededForUsers = true; };

  services.numtide-rke2.enable = true;
  services.numtide-rke2.configFile = config.sops.templates."config.yaml".path;
  services.numtide-rke2.manifests = {
    "cilium-config.yaml" = config.sops.templates."cilium-config.yaml".path;
  };

  sops.templates."cilium-config.yaml".content = ''
    apiVersion: helm.cattle.io/v1
    kind: HelmChartConfig
    metadata:
      name: rke2-cilium
      namespace: kube-system
    spec:
      valuesContent: |-
        ipam:
          operator:
            clusterPoolIPv4PodCIDRList: ["10.100.0.0/16"]
        k8sServiceHost: ${config.sops.placeholder.internalNodeIp}
        k8sServicePort: 6443
        l2announcements:
          enabled: true
        kubeProxyReplacement: true
        bpf:
          masquerade: true
          lbExternalClusterIP: false
        gatewayAPI:
          enabled: false
        routingMode: "tunnel"
        tunnelProtocol: "vxlan"
        ingressController:
          enabled: true
          default: true
          loadbalancerMode: "dedicated"
          service:
            name: "cilium-ingress-external"
            labels:
              "k3s-paas/internal": "true"
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
              - "dns"
              - "drop"
              - "tcp"
              - "flow"
              - "port-distribution"
              - "icmp"
              - "httpV2:exemplars=true;labelsContext=source_ip,source_namespace,source_workload,destination_ip,destination_namespace,destination_workload,traffic_direction"
            enableOpenMetrics: true
  '';

  sops.templates."config.yaml".content = ''
    advertise-address: ${config.sops.placeholder.internalNodeIp}
    node-name: "${config.networking.hostName}"
    cluster-domain: ${config.sops.placeholder.paasDomain}
    node-external-ip: "${config.sops.placeholder.nodeIp}"
    cluster-cidr: 10.100.0.0/16
    service-cidr: 10.110.0.0/16
    cluster-dns: 10.110.0.10
    vpn-auth: "name=tailscale,joinKey=${config.sops.placeholder.tailscaleNodeKey}"
    tls-san:
      - localhost
      - 10.43.0.1
      - ${config.networking.hostName}
      - "${config.sops.placeholder.tailscaleDomain}"
      - "${config.sops.placeholder.nodeIp}"
      - "${config.sops.placeholder.internalNodeIp}"

    cni: cilium
    protect-kernel-defaults: true

    kube-apiserver-arg:
      - '--authorization-mode=Node,RBAC'
      - '--oidc-issuer-url=https://dex.${config.sops.placeholder.paasDomain}'
      - '--oidc-client-id=${dex.dexClientId}'
      - '--oidc-username-claim=email'
      - '--oidc-groups-claim=groups'
      - '--default-not-ready-toleration-seconds=30'
      - '--default-unreachable-toleration-seconds=30'

    kube-controller-manager-arg:
      - '--node-monitor-period=4s'
    kubelet-arg:
      - '--node-status-update-frequency=4s'
      - '--max-pods=100'

    etcd-arg: "--quota-backend-bytes 2048000000"
    etcd-snapshot-schedule-cron: "0 3 * * *"
    etcd-snapshot-retention: 10
  '';

  users.users.reader.hashedPasswordFile = config.sops.secrets.password.path;
  users.users.${user.name}.hashedPasswordFile = config.sops.secrets.password.path;
  users.users.root.hashedPasswordFile = config.sops.secrets.password.path;
}
