#!/usr/bin/env bash

eval "$(jq -r '@sh "timeout=\(.timeout) mac=\(.mac)"')"

elapsed=0
ip_address=""

while [ -z "$ip_address" ] && [ $elapsed -lt ${timeout:-90} ]; do
  ip_address=$(arp -a | grep "$mac" | awk -F'[()]' '{print $2}')
  if [ -n "$ip_address" ]; then
    export ip_address
    break
  fi

  elapsed=$((elapsed + 10))

done

jq -n --arg output "$ip_address" '{"ip": $output}'
