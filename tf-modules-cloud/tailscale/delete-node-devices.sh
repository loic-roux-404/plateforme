#!/usr/bin/env bash

ENDPOINT=${ENDPOINT:-https://api.tailscale.com}
API_KEY=$(curl -s -d "client_id=$OAUTH_CLIENT_ID" -d "client_secret=$OAUTH_CLIENT_SECRET" \
  "${ENDPOINT}/api/v2/oauth/token" | jq -r '.access_token')
NODE_HOSTNAMES=${NODE_HOSTNAMES:-}

IFS=',' read -ra ADDR <<< "$NODE_HOSTNAMES"
for NODE_HOSTNAME in "${ADDR[@]}"; do

    curl -s "${ENDPOINT}/api/v2/tailnet/$TAILNET/devices" -u "$API_KEY:" | jq -r '.devices[] |  "\(.id) \(.name)"' |
    while read -r id name; do
        if [[ $name = *"$NODE_HOSTNAME.$TAILNET"* ]]
        then
        echo "$name matching $NODE_HOSTNAME.$TAILNET - getting rid of $id"
        curl -s -X DELETE "${ENDPOINT}/api/v2/device/$id" -u "$API_KEY:"
        else
        echo "$name not matching $NODE_HOSTNAME.$TAILNET, keeping it"
        fi
    done
done
