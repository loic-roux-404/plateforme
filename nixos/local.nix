# Local libvirt VM specifics — included ONLY in the local image attrs
# (initial / deploy / deploy-bootstrap). Contabo builds never see this module.
{ lib, config, ... }:

with config.paas;
{
  # Static lease on the vmnet-shared bridge (host = 192.168.2.1). Kills the
  # DHCP churn that previously invalidated arp entries, dnsmasq wildcard
  # records and the pebble/minio gateway reachability on every VM reset.
  # Keep in sync with paas.kube.addr on the darwin host (dnsmasq wildcard).
  paas.kube.addr = "192.168.2.100";
  networking.interfaces.enp0s9 = {
    useDHCP = lib.mkForce false;
    ipv4.addresses = [{ address = kube.addr; prefixLength = 24; }];
  };
  networking.defaultGateway = {
    address = "192.168.2.1";
    interface = "enp0s9";
  };

  # The apiserver (a host process) resolves the dex issuer itself: CoreDNS
  # host-rewrite patches only cover in-cluster lookups.
  networking.extraHosts = ''
    ${kube.addr} dex.${dns.name} ${dns.name} oauth2.${dns.name} longhorn.${dns.name}
  '';

  # Pebble-issued ingress certs (dex) verified by the apiserver during OIDC
  # discovery — root CA shipped as a transient sops secret by the network layer.
  paas.kube.importLocalAcmeCa = true;
}
