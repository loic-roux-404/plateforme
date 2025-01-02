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

  # services.rke2.configPath = config.sops.templates."config.yaml".path;  
  # sops.templates."config.yaml".content = ''
  #   with-node-id: true
  #   cluster-domain: ${config.sops.placeholder.paasDomain}
  #   advertise-address: ${config.sops.placeholder.internalNodeIp}
  #   node-external-ip: "${config.sops.placeholder.nodeIp}"
  #   cluster-cidr: ${kube.podCIDR}
  #   service-cidr: ${kube.serviceCIDR}
  #   cluster-dns: ${kube.clusterDns}
  #   node-taint:
  #     - "CriticalAddonsOnly=true:NoExecute"
  #   tls-san:
  #     - "${kube.serviceIp}"
  #     - "${config.networking.hostName}"
  #     - "${config.sops.placeholder.nodeIp}"
  #     - "${config.sops.placeholder.internalNodeIp}"
  #   kube-apiserver-arg=authorization-mode: Node,RBAC
  #   kube-apiserver-arg=oidc-issuer-url: https://dex.${config.sops.placeholder.paasDomain}
  #   kube-apiserver-arg=oidc-client-id: ${dex.dexClientId}
  #   kube-apiserver-arg=oidc-username-claim: email
  #   kube-apiserver-arg=oidc-groups-claim: groups
  # '';
}
