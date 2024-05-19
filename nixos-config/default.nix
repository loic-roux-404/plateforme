{ lib, ... }:

{
  options.k3s-paas = {

    certs = lib.mkOption {
      default = ["https://localhost:15000/intermediates/0"] ;
      type = lib.types.listOf (lib.types.str);
      description = "Ca url to fetch and trust (need to be impure)";
    };

    dns.name = lib.mkOption {
      default = "k3s.test";
      type = lib.types.str;
      description = "hostname for k3s-paas";
    };

    dns.dest-ip = lib.mkOption {
      default = "127.0.0.1";
      type = lib.types.str;
      description = "Target IP address for dns.name";
    };

    user.name = lib.mkOption {
      default = "zizou";
      type = lib.types.str;
      description = "User name";
    };

    user.password = lib.mkOption {
      default = "$6$zizou$reVO3q7LFsUq.GT5P5pYFFcpxCo7eTRT5yJTD.gVoOy/FSzHEtXdofvZ7E04Rej.jiQHKaWJB0Qob5FHov1WU/";
      type = lib.types.str;
      description = "User password";
    };

    user.key = lib.mkOption {
      default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC94/4uRn429xMGLFWZMyJWlhb5D0L3EoO8HxzN4q1ps loic@Windows-8-Phone.local";
      type = lib.types.str;
      description = "SSH public key for k3s-paas.";
    };

    k3s.disableServices = lib.mkOption {
      default = "traefik";
      type = lib.types.str;
      description = "Disable k3s services eg: traefik,servicelb";
    };

    k3s.token = lib.mkOption {
      default = "example-token";
      type = lib.types.str;
      description = "K3s token";
    };

    dex.dex_client_id = lib.mkOption {
      default = "client-id";
      type = lib.types.str;
      description = "Client ID for Dex";
    };
  };
}
