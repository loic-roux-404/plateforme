{ name, nodes, ... }: {
  deployment.tags = [ "agent" ];
  networking.hostName = name;
  services.k3s.serverAddr = nodes.k3s-paas-master.config.networking.hostName;
}
