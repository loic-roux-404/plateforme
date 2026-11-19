#!/usr/bin/env bash

eval "$(jq -r '@sh "timeout=\(.timeout) mac=\(.mac)"')"

elapsed=0
ip_address=""

# stale arp entries persist for the MAC across VM resets (new DHCP lease per
# boot); only the candidate with sshd answering is the live VM
while [ -z "$ip_address" ] && [ $elapsed -lt ${timeout:-90} ]; do
  for candidate in $(arp -a | grep "$mac" | awk -F'[()]' '{print $2}' | sort -u); do
    if /usr/bin/nc -z -G 1 "$candidate" 22 >/dev/null 2>&1; then
      ip_address=$candidate
      break
    fi
  done

  [ -n "$ip_address" ] && break

  elapsed=$((elapsed + 10))
  sleep 10
done

if [ -z "$ip_address" ]; then
  echo "get-ip.sh: no SSH-reachable candidate for MAC $mac within ${timeout:-90}s; arp candidates: $(arp -a | grep "$mac" | awk -F'[()]' '{print $2}' | sort -u | tr '\n' ' ')" >&2
  exit 1
fi

jq -n --arg output "$ip_address" '{"ip": $output}'
