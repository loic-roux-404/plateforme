{ config,  ... } : 

with config.paas;
{
  networking.hostName = "localhost-0";
  
  users.users.${user.name}.hashedPasswordFile = config.sops.secrets.password.path;
  users.users.root.hashedPasswordFile = config.sops.secrets.password.path;

  sops.validateSopsFiles = false;
  sops.defaultSopsFormat = "yaml";
  sops.defaultSopsFile = "/home/${user.name}/secrets.yaml";
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" "${config.sops.secrets.nodePrivateKey.path}" ];

  sops.secrets = {
    nodeIp = {};
    internalNodeIp = {};
    nodePrivateKey = {
      neededForUsers = true;
    };
    paasDomain = {};
    password = { neededForUsers = true; };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  paas.k3s.serverExtraArgs = [ "--disable-kube-proxy" ];

  paas.ciliumConfigPath = config.sops.templates."cilium-config.yaml".path;
  sops.templates."cilium-config.yaml".content = ''
    apiVersion: helm.cattle.io/v1
    kind: HelmChartConfig
    metadata:
      name: rke2-cilium
      namespace: kube-system
    spec:
      valuesContent: |-
        kubeProxyReplacement: true
        k8sServiceHost: 127.0.0.1
        k8sServicePort: "${k3s.servicePort}"
        routingMode: tunnel
        tunnelProtocol: vxlan
        ipam:
          operator:
            clusterPoolIPv4PodCIDRList:
              - "${k3s.podCIDR}"
        bpf:
          masquerade: true
          lbExternalClusterIP: true
        l2announcements:
          enabled: true
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
              kube-paas/internal: "true"
        prometheus:
          enabled: true
          serviceMonitor:
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
  '';

  services.rke2.configPath = config.sops.templates."config.yaml".path;  
  sops.templates."config.yaml".content = ''
    with-node-id: true
    cluster-domain: ${config.sops.placeholder.paasDomain}
    advertise-address: ${config.sops.placeholder.internalNodeIp}
    node-external-ip: "${config.sops.placeholder.nodeIp}"
    cluster-cidr: ${k3s.podCIDR}
    service-cidr: ${k3s.serviceCIDR}
    cluster-dns: ${k3s.clusterDns}
    node-taint:
      - "CriticalAddonsOnly=true:NoExecute"
    tls-san:
      - "${k3s.serviceIp}"
      - "${config.networking.hostName}"
      - "${config.sops.placeholder.nodeIp}"
      - "${config.sops.placeholder.internalNodeIp}"
    kube-apiserver-arg=authorization-mode: Node,RBAC
    kube-apiserver-arg=oidc-issuer-url: https://dex.${config.sops.placeholder.paasDomain}
    kube-apiserver-arg=oidc-client-id: ${dex.dexClientId}
    kube-apiserver-arg=oidc-username-claim: email
    kube-apiserver-arg=oidc-groups-claim: groups
  '';
}
