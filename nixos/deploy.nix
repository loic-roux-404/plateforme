{ lib, config,  ... } : 

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
    nodePrivateKey = {
      neededForUsers = true;
    };
    paasDomain = {};
    password = { neededForUsers = true; };
  };

  paas.defaultKubeDistribConfigPath = lib.mkForce config.sops.templates."config.yaml".path;

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
  };

  sops.templates."config.yaml".content = ''
    with-node-id: true
    advertise-address: ${config.sops.placeholder.nodeIp}
    node-external-ip: "${config.sops.placeholder.nodeIp}"
    cluster-cidr: ${kube.podCIDR}
    service-cidr: ${kube.serviceCIDR}
    node-taint:
      - "CriticalAddonsOnly=true:NoExecute"
    tls-san:
      - "${kube.serviceIp}"
      - "${config.networking.hostName}"
      - "${config.sops.placeholder.nodeIp}"
      - "${config.sops.placeholder.paasDomain}"
    kube-apiserver-arg=authorization-mode: Node,RBAC
    kube-apiserver-arg=oidc-issuer-url: https://dex.${config.sops.placeholder.paasDomain}
    kube-apiserver-arg=oidc-client-id: ${dex.dexClientId}
    kube-apiserver-arg=oidc-username-claim: email
    kube-apiserver-arg=oidc-groups-claim: groups
  '';
}
