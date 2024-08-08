{ lib, ... }:

{
  options.k3s-paas = {

    certs = lib.mkOption {
      default = [{
        url = "https://localhost:15000/intermediates/0";
        sha256 = "06fpbiljbzmcnfsxnr92p7mhm6i4yglbhj5q7csw2pcsklw68z8n";
      }];
      type = lib.types.listOf (lib.types.attrs);
      description = "Ca url to fetch and trust (need to be impure)";
    };

    dns.name = lib.mkOption {
      default = "k3s.test";
      type = lib.types.str;
      description = "hostname for k3s-paas";
    };

    dns.dest-ips = lib.mkOption {
      default = ["127.0.0.1" "192.168.205.5" "192.168.205.6" "192.168.205.7" "192.168.205.8" "192.168.205.9"];
      type = lib.types.listOf lib.types.str;
      description = "Target IP address for dns.name (only in local dev)";
    };

    user.name = lib.mkOption {
      default = "admin";
      type = lib.types.str;
      description = "User name";
    };

    user.defaultPassword = lib.mkOption {
      default = "$6$zizou$reVO3q7LFsUq.GT5P5pYFFcpxCo7eTRT5yJTD.gVoOy/FSzHEtXdofvZ7E04Rej.jiQHKaWJB0Qob5FHov1WU/";
      type = lib.types.str;
      description = "Default password for user";
    };

    user.key = lib.mkOption {
      default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC94/4uRn429xMGLFWZMyJWlhb5D0L3EoO8HxzN4q1ps loic@Windows-8-Phone.local";
      type = lib.types.str;
      description = "SSH public key for k3s-paas.";
    };

    k8s.disableServices = lib.mkOption {
      default = ["traefik" "metrics-server" "servicelb" ];
      type = lib.types.listOf lib.types.str;
      description = "Disable k8s services eg: traefik,servicelb";
    };

    k8s.serverExtraArgs = lib.mkOption {
      default = [];
      type = lib.types.listOf lib.types.str;
      description = "Extra arguments for k8s server";
    };

    k8s.token = lib.mkOption {
      type = lib.types.str;
      description = "K3s token";
      default = "";
    };

    dex.dexClientId = lib.mkOption {
      type = lib.types.str;
      description = "Client ID for Dex";
      default = "dex-k3s-paas";
    };

  };
}
