#!/bin/bash

############################################################
#
# Install dnsmasq and configure it to resolve wildcard domains
# to a specific IP address.
#
############################################################

set -e

WILDCARD_DOMAIN="${1:-k3s.test}"
TARGET_IP="${2:-127.0.0.1}"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    DNSMASQ_CNF="/etc/dnsmasq.conf"
    sudo apt update && sudo apt install -y dnsmasq
    sudo systemctl disable systemd-resolved
    sudo systemctl stop systemd-resolved
    sudo rm -rf /etc/resolv.conf
    echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf
    sudo chattr +i /etc/resolv.conf

    sudo tee -a $DNSMASQ_CNF <<EOF 
server=8.8.8.8
server=8.8.4.4
port=53
address=/.$WILDCARD_DOMAIN/$TARGET_IP
EOF
    sudo systemctl restart dnsmasq

elif [[ "$OSTYPE" == "darwin"* ]]; then
    DNSMASQ_CNF="$(brew --prefix)/etc/dnsmasq.conf"
    brew install dnsmasq
    mkdir -pv "$(brew --prefix)/etc/"
    echo 'port=53' >> "$DNSMASQ_CNF"
    echo "address=/.$WILDCARD_DOMAIN/$TARGET_IP" >> "$DNSMASQ_CNF"
    sudo mkdir -v /etc/resolver
    echo "nameserver $TARGET_IP" | sudo tee "/etc/resolver/$WILDCARD_DOMAIN"

    sudo brew services restart dnsmasq
fi
