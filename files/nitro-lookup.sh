#! /bin/bash

ENCLAVE_CID=$(nitro-cli describe-enclaves | jq -r ".[0].EnclaveCID")
encoded=$(echo $1 | base64 -w 0)
# echo $encoded
# echo $encoded | base64 -d
python3 /var/tmp/enclave_client.py client ${ENCLAVE_CID} 5005 ${encoded}
