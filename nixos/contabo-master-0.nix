{ lib, ... }: {
  networking.hostName = lib.mkForce "contabo-master-0";
}
