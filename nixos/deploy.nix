{ config, ... } : 

with config.k3s-paas;

{
  sops.validateSopsFiles = false;
  sops.defaultSopsFormat = "yaml";
  sops.defaultSopsFile = "/home/${user.name}/secrets.yaml";
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  sops.secrets.password = {
    neededForUsers = true;
  };

  networking.hostName = "contabo-master-0";

  users.users.reader.hashedPasswordFile = config.sops.secrets.password.path;
  users.users.${user.name}.hashedPasswordFile = config.sops.secrets.password.path;
  users.users.root.hashedPasswordFile = config.sops.secrets.password.path;
}
