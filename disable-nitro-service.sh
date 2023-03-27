#! /bin/bash

sudo systemctl stop nitro-lookup
sudo systemctl disable nitro-lookup
docker rmi -f $(docker images -a -q)
sudo systemctl reset-failed
