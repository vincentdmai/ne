# // Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# // SPDX-License-Identifier: MIT-0
import argparse
import socket
import sys
import json
import redis
import base64
import pickle
import time

NUMBER_BYTES_IN_KB = 1024
MAX_RECV_ALLOC_KB = 64 * NUMBER_BYTES_IN_KB

redis_client = redis.Redis(unix_socket_path='/run/redis.sock')


class VsockListener:
    # Server
    def __init__(self, conn_backlog=128):
        self.conn_backlog = conn_backlog

    def bind(self, port):
        # Bind and listen for connections on the specified port
        self.sock = socket.socket(socket.AF_VSOCK, socket.SOCK_STREAM)
        self.sock.bind((socket.VMADDR_CID_ANY, port))
        self.sock.listen(self.conn_backlog)

    def recv_data(self):
        # Receive data from a remote endpoint
        while True:
            try:
                print("Awaiting...")
                (from_client, (remote_cid, remote_port)) = self.sock.accept()
                print("Connection from " + str(from_client) +
                      str(remote_cid) + str(remote_port))

                byte_data = b""
                while True:
                    chunk = from_client.recv(MAX_RECV_ALLOC_KB)
                    byte_data += chunk
                    if len(chunk) == 0 or byte_data[-5:] == b"<END>":
                        byte_data = byte_data[:len(byte_data)-5]
                        print("BROKE")
                        break

                query = pickle.loads(base64.b64decode(byte_data))

                # Will receive tuple in the format (COMMAND, ID, DATA)
                query_type = query[0].lower()
                data_key = query[1]
                data = query[2]

                if query_type == 'get':
                    response = get_values_in_redis(data)
                elif query_type == 'set':
                    response = put_in_redis(data_key, data)
                elif query_type == 'delete':
                    response = delete_in_redis(data)
                else:
                    response = "Bad query type"

                # Send back the response
                from_client.sendall(base64.b64encode(pickle.dumps(response)))
                from_client.send(b"<END>")

                from_client.close()
                print("Client call closed")
            except Exception as ex:
                print(ex)


def server_handler(args):
    server = VsockListener()
    server.bind(args.port)
    print("Started listening to port : ", str(args.port))
    server.recv_data()


def get_values_in_redis(keys):
    if len(keys) == 0:
        return {}

    all_values = [json.loads(value.decode())
                  for value in redis_client.mget(keys)]
    return dict(zip(keys, all_values))


def put_in_redis(key, value):
    return redis_client.set(key, value)
  
  
def delete_in_redis(keys):
	return [key for key in keys if redis_client.delete(key)]


def main():
    parser = argparse.ArgumentParser(prog='vsock-sample')
    parser.add_argument("--version", action="version",
                                            help="Prints version information.",
                                            version='%(prog)s 0.1.0')
    subparsers = parser.add_subparsers(title="options")

    server_parser = subparsers.add_parser("server", description="Server",
                                          help="Listen on a given port.")
    server_parser.add_argument(
        "port", type=int, help="The local port to listen on.")
    server_parser.set_defaults(func=server_handler)

    if len(sys.argv) < 2:
        parser.print_usage()
        sys.exit(1)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
