{ config,  ... } : 

with config.paas;
{
  networking.hostName = "localhost-0";
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
    tailscaleNodeKey = {};
    paasDomain = {};
    tailscaleDomain = {};
    password = { neededForUsers = true; };
  };

  #networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.tailscale.authKeyFile = config.sops.secrets.tailscaleNodeKey.path;
  services.tailscale.extraUpFlags = [
    "--ssh" "--hostname=${config.networking.hostName}" 
  ];

  services.openssh.hostKeys = [
    {
      path = config.sops.secrets.nodePrivateKey.path;
      type = "ed25519";
    }
    {
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
  ];

  kube-paas.k3s.serverExtraArgs = [ "--disable-kube-proxy" ];

  environment.etc."rke2/cilium-config.yaml".source = config.sops.templates."cilium-config.yaml".path;
  sops.templates."cilium-config.yaml".content = ''
    apiVersion: helm.cattle.io/v1
    kind: HelmChartConfig
    metadata:
      name: rke2-cilium
      namespace: kube-system
    spec:
      valuesContent: |-
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
              kube-paas/internal: "true"
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
        k8sServiceHost: "${config.sops.placeholder.internalNodeIp}"
        k8sServicePort: "${k3s.servicePort}"
  '';

  services.rke2.configPath = config.sops.templates."config.yaml".path;  
  sops.templates."config.yaml".content = ''
    with-node-id: true
    advertise-address: ${config.sops.placeholder.internalNodeIp}
    cluster-domain: ${config.sops.placeholder.paasDomain}
    node-external-ip: "${config.sops.placeholder.nodeIp}"
    cluster-cidr: ${k3s.podCIDR}
    service-cidr: ${k3s.serviceCIDR}
    cluster-dns: ${k3s.clusterDns}
    vpn-auth: "name=tailscale,joinKey=${config.sops.placeholder.tailscaleNodeKey}"
    node-taint:
      - "CriticalAddonsOnly=true:NoExecute"
    tls-san:
      - "${k3s.serviceIp}"
      - "${config.networking.hostName}"
      - "${config.sops.placeholder.tailscaleDomain}"
      - "${config.sops.placeholder.nodeIp}"
      - "${config.sops.placeholder.internalNodeIp}"
    kube-apiserver-arg=authorization-mode: Node,RBAC
    kube-apiserver-arg=oidc-issuer-url: https://dex.${config.sops.placeholder.paasDomain}
    kube-apiserver-arg=oidc-client-id: ${dex.dexClientId}
    kube-apiserver-arg=oidc-username-claim: email
    kube-apiserver-arg=oidc-groups-claim: groups
  '';

  users.users.${user.name}.hashedPasswordFile = config.sops.secrets.password.path;
  users.users.root.hashedPasswordFile = config.sops.secrets.password.path;
}
