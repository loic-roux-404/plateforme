#!/usr/bin/env bash

set -euo pipefail

eval "$(jq -r '@sh "machine_ip=\(.machine_ip)"')"

OUTPUT=$(ssh-keyscan -p 22 -t ed25519 "$machine_ip" | ssh-to-age || echo '')

jq -n --arg output "$OUTPUT" '{"key": $output}'

