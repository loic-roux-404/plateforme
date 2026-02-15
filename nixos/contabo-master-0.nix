{ lib, ... }: {
  networking.hostName = lib.mkForce "contabo-master-0";
  dns.otherServers = [];
}
