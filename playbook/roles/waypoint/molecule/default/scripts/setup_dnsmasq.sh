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
    sudo systemctl stop systemd-resolved
    echo 'DNSStubListener=no' | sudo tee -a /etc/systemd/resolved.conf
    sudo systemctl start systemd-resolved
    sudo apt install -y dnsmasq
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
    brew install dnsmasq && brew upgrade dnsmasq
    mkdir -pv "$(brew --prefix)/etc/"
    DNSMASQ_CNF="$(brew --prefix)/etc/dnsmasq.conf"

    sudo tee -a $DNSMASQ_CNF <<EOF
port=53
address=/.$WILDCARD_DOMAIN/$TARGET_IP
EOF
    sudo mkdir -v /etc/resolver
    echo "nameserver $TARGET_IP" | sudo tee "/etc/resolver/$WILDCARD_DOMAIN"

    sudo -E brew services restart dnsmasq
fi

# Test
ping -c 1 k3s.test
