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
  sops.secrets.nodePrivateKey = {
    neededForUsers = true;
  };
  sops.secrets.tailscaleNodeKey = {};
  sops.secrets.paasDomain = {};
  sops.secrets.tailscaleDomain = {};
  sops.secrets.password = { neededForUsers = true; };

  services.k3s.enable = true;
  services.k3s.configPath = config.sops.templates."config.yaml".path;

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
    kube-apiserver-arg=authorization-mode: Node,RBAC
    kube-apiserver-arg=oidc-issuer-url: https://dex.${config.sops.placeholder.paasDomain}
    kube-apiserver-arg=oidc-client-id: ${dex.dexClientId}
    kube-apiserver-arg=oidc-username-claim: email
    kube-apiserver-arg=oidc-groups-claim: groups
  '';

  users.users.reader.hashedPasswordFile = config.sops.secrets.password.path;
  users.users.${user.name}.hashedPasswordFile = config.sops.secrets.password.path;
  users.users.root.hashedPasswordFile = config.sops.secrets.password.path;
}
