#!/usr/bin/env bash

set -euo pipefail

eval "$(jq -r '@sh "location=\(.location) user=\(.user) host=\(.host) key=\(.key)"')"

OUTPUT=$(ssh -i "${key:-$HOME/.ssh/id_ed25519}" -o StrictHostKeyChecking=no $user@$host "sudo cat $location")

jq -n --arg output "$OUTPUT" '{"config": $output}'
