#!/usr/bin/env bash

eval "$(jq -r '@sh "key=\(.key) args=\(.args)"')"

OUTPUT=$(echo "$key" | ssh-to-age "${args:-}")

jq -n --arg output "$OUTPUT" '{"key": $output}'
