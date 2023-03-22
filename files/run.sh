# // Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# // SPDX-License-Identifier: MIT-0

#!/bin/sh

# Run traffic forwarder in background and start the server
redis-server /usr/local/etc/redis/redis.conf &
python3 /app/server.py server 5005
