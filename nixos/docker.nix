{ lib , ... }:
{
  networking.useHostResolvConf = lib.mkForce false;
  services.resolved.enable = true;
}