#!/usr/bin/env bash

read_tfvar() {
    local var_name=$1
    grep "$var_name" prod.tfvars | cut -d'=' -f2 | tr -d ' ' | tr -d \"
}

CLIENT_ID=$(read_tfvar oauth2_client_id)
CLIENT_SECRET=$(read_tfvar oauth2_client_secret)
API_USER=$(read_tfvar oauth2_user)
API_PASSWORD=$(read_tfvar oauth2_pass)

cntb config set-credentials --oauth2-clientid="$CLIENT_ID" \
    --oauth2-client-secret="$CLIENT_SECRET" --oauth2-user="$API_USER" \
    --oauth2-password="$API_PASSWORD"
