#!/usr/bin/env bash

set -euo pipefail

eval "$(jq -r '@sh "name=\(.name)"')"

OUTPUT=$(tailscale ip -4 $name)

jq -n --arg output "$OUTPUT" '{"ip": $output}'
