{ lib, name, nodes, ... }: {
  imports = [ ./k3s-paas-common.nix ];

  deployment.tags = lib.mkDefault [ "agent" ];
  networking.hostName = lib.mkForce name;
  services.k3s.serverAddr = nodes.k3s-paas-master.config.networking.hostName;
}
