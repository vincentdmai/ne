#! /bin/bash

sudo systemctl enable nitro-lookup
sudo systemctl start nitro-lookup
sudo journalctl -u nitro-lookup -f
