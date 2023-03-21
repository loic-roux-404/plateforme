#!/bin/bash

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    DNSMASQ_CNF_DIR="/etc/dnsmasq.conf"
    sudo systemctl disable systemd-resolved
    sudo systemctl stop systemd-resolved
    ls -lh /etc/resolv.conf
    sudo rm /etc/resolv.conf
    sudo apt-get install -y dnsmasq
    echo 'port=53' >>  /etc/dnsmasq.conf
    echo 'address=/.k3s.test/127.0.0.1' >> $DNSMASQ_CNF_DIR
    sudo systemctl restart dnsmasq

elif [[ "$OSTYPE" == "darwin"* ]]; then
    DNSMASQ_CNF_DIR="$(brew --prefix)/etc/dnsmasq.conf"
    brew install dnsmasq
    mkdir -pv "$(brew --prefix)/etc/"
    echo 'port=53' >> "$DNSMASQ_CNF_DIR"
    echo 'address=/.k3s.test/127.0.0.1' >>  "$DNSMASQ_CNF_DIR"
    sudo mkdir -v /etc/resolver
    echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/k3s.test

    sudo brew services restart dnsmasq
fi