#!/bin/bash

sudo apt autoremove -y --purge
sudo apt autoclean -y
sudo journalctl --rotate
sudo journalctl --vacuum-size 10M

# Zero out the free space to save space in the final image:
sudo dd if=/dev/zero of=zero.small.file bs=1024 count=102400
sudo dd if=/dev/zero of=zero.file bs=1024
sudo sync ; sleep 60 ; sudo sync
sudo rm zero.small.file
sudo rm zero.file
