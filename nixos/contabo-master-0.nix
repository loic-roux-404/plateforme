{ lib, ... }: {
  networking.hostName = lib.mkForce "contabo-master-0";
  system.preSwitchChecks = lib.mkForce {};

  networking = {
    interfaces.ens18.useDHCP = true;
    firewall = {
      interfaces.ens18 = {
        allowedTCPPorts = lib.mkDefault [ 80 443 22 4240 8472 2379 6443 ];
      };
    };
  };
}
