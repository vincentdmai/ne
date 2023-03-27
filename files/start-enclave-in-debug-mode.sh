#! /bin/bash

/bin/terminate-enclave.sh
docker build /var/tmp -t secure-channel-example
nitro-cli run-enclave --cpu-count 2 --memory 2096 --eif-path secure-channel-example.eif --debug-mode --attach-console
