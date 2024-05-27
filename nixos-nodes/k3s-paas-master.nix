{ lib, name, ... }: {
  imports = [ 
    ./k3s-paas-common.nix 
  ];

  deployment.tags = lib.mkDefault [ "master" ];
  networking.hostName = lib.mkForce name;
  services.k3s.clusterInit = true;
}
