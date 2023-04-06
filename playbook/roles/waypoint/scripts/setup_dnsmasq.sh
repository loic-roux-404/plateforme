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
    DNSMASQ_CNF_DIR="/etc/dnsmasq.conf"
    sudo systemctl disable systemd-resolved
    sudo systemctl stop systemd-resolved
    ls -lh /etc/resolv.conf
    sudo rm /etc/resolv.conf
    sudo apt-get install -y dnsmasq
    echo 'port=53' >>  /etc/dnsmasq.conf
    echo "address=/.$WILDCARD_DOMAIN/$TARGET_IP" >> $DNSMASQ_CNF_DIR
    sudo systemctl restart dnsmasq

elif [[ "$OSTYPE" == "darwin"* ]]; then
    DNSMASQ_CNF_DIR="$(brew --prefix)/etc/dnsmasq.conf"
    brew install dnsmasq
    mkdir -pv "$(brew --prefix)/etc/"
    echo 'port=53' >> "$DNSMASQ_CNF_DIR"
    echo "address=/.$WILDCARD_DOMAIN/$TARGET_IP" >>  "$DNSMASQ_CNF_DIR"
    sudo mkdir -v /etc/resolver
    echo "nameserver $TARGET_IP" | sudo tee "/etc/resolver/$WILDCARD_DOMAIN"

    brew services restart dnsmasq
fi
