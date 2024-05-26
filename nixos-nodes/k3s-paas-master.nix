{ name, ... }: {
  deployment.tags = [ "master" ];
  networking.hostName = name;

  services.k3s.clusterInit = true;
}
