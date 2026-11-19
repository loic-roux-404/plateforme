#!/usr/bin/env bash

set -euo pipefail

eval "$(jq -r '@sh "location=\(.location) user=\(.user) host=\(.host) key=\(.key)"')"

# key arrives as the literal "null" when the caller omits it (jq @sh of a
# missing field) — treat that as unset, not as a file named null
[ "$key" = "null" ] && key=""

# The host comes from cloud-layer state: after a reboot (nix deploy, VM
# recreation) the guest can hold a different DHCP lease than the one recorded,
# so a first-attempt connection failure is retried. ssh returns 255 for both
# transport and auth failures, so a bad key costs 60s of retries before failing.
err=$(mktemp)
trap 'rm -f "$err"' EXIT
attempt=0
until OUTPUT=$(ssh -i "${key:-$HOME/.ssh/id_ed25519}" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$user@$host" "sudo cat $location" 2>"$err"); do
  rc=$?
  if [ "$rc" -ne 255 ] || [ "$attempt" -ge 12 ]; then
    cat "$err" >&2
    exit "$rc"
  fi
  attempt=$((attempt + 1))
  sleep 5
done

jq -n --arg output "$OUTPUT" '{"config": $output}'
