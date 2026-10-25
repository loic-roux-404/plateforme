#!/usr/bin/env bash
# Print the Linux builder VM's `vmnet-shared` address (the VM itself is
# configured in ./configuration.nix under `nix.linux-builder`). Its NIC uses a
# fixed MAC, so the DHCP lease on `bridge100` always maps back to the same
# guest.
#
# Reads the lease file first because macOS only populates the ARP entry once
# something has talked to the guest; falls back to ARP.
#
# Runnable standalone (`./linux-builder-ip.sh`, needs only `awk` + `arp` on
# PATH) or wrapped as the `linux-builder-ip` command by ./linux-builder-ip.nix.
set -eu

mac="de:ad:be:ef:aa:bb"
leases=/var/db/dhcpd_leases

ip=$(awk -v mac="${mac}" '
  /^\{/ { block = "" }
  { block = block $0 "\n" }
  /^\}/ {
    if (index(block, "hw_address=1," mac)) {
      n = split(block, lines, "\n")
      for (i = 1; i <= n; i++) {
        if (lines[i] ~ /^[[:space:]]*ip_address=/) {
          sub(/.*ip_address=/, "", lines[i])
          print lines[i]
          exit
        }
      }
    }
  }
' "${leases}" 2>/dev/null || true)

if [ -z "${ip}" ]; then
  ip=$(arp -an | awk -v m="${mac}" \
    'index($0, m) { gsub(/[()]/, "", $2); print $2; exit }')
fi

if [ -z "${ip}" ]; then
  echo "linux-builder-ip: no lease for ${mac}; is the builder VM running?" >&2
  echo "  sudo launchctl list | grep org.nixos.linux-builder" >&2
  exit 1
fi

echo "${ip}"
