#! /bin/bash

/bin/terminate-enclave.sh
docker build /var/tmp -t secure-channel-example
nitro-cli build-enclave --docker-uri secure-channel-example:latest --output-file secure-channel-example.eif
nitro-cli run-enclave --cpu-count 2 --memory 2096 --eif-path secure-channel-example.eif
