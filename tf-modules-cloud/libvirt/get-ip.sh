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

jq -n --arg output "$ip_address" '{"ip": $output}'
