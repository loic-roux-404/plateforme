#!/bin/bash
# REQS:
# - k3s is running with MetalLB

##########
# Host
##########

#first delete any old route to 172.18
sudo route -nv delete -net 172.18

# show members of the bridge vnet
ifconfig bridge100

# get IP addr on the lima0 interface
RD_IP=$(rdctl shell -- ip -o -4 a s | grep rd0 | grep -E -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut -d' ' -f2)
echo "Rancker desktop ip : $RD_IP"

# add route to the Rancher desktop Lima VM
sudo route -nv add -net 172.18 "${RD_IP}"

# check route
route get 172.18.1.1
#traceroute 172.18.1.1

# delete route
#sudo route -nv delete -net 172.18 ${RD_IP}
