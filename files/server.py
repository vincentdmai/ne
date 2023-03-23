# // Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# // SPDX-License-Identifier: MIT-0
import argparse
import socket
import sys
import json
import redis
import base64
import pickle

redis_client = redis.Redis(unix_socket_path='/run/redis.sock')

# Running server you have to pass port the server
# $ python3 /app/server.py server <port>
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
				print("Connection from " + str(from_client) + str(remote_cid) + str(remote_port))
				
				# Receive connections from other end of socket
				query = pickle.loads(base64.b64decode(from_client.recv(sys.maxsize)))
				print("Message received: {}".format(query))
    
				# Will receive tuple in the format (COMMAND, ID, DATA)
				query_type = query[0].lower()
				data_key = query[1]
				data = query[2]
				
				print("{} {}".format(query_type, data))
				if query_type == 'get':
					response = get_all_in_redis()
				elif query_type == 'set':
					response = put_in_redis(data_key, data)
				else:
					response = "Bad query type"
     
				print(str(response))
    
				# Send back the response
				from_client.send(str(response).encode())
	
				from_client.close()
				print("Client call closed")
			except Exception as ex:
				print(ex)

def server_handler(args):
	server = VsockListener()
	server.bind(args.port)
	print("Started listening to port : ", str(args.port))
	server.recv_data()

def put_in_redis(key, value):
	redis_client.set(key, value)
	print("Setting {} to {}".format(key, value))
	return "SUCCESS"

# Get list of current ip ranges for the S3 service for a region.
# Learn more here: https://docs.aws.amazon.com/general/latest/gr/aws-ip-ranges.html#aws-ip-download 
# def get_all_in_redis(query):
# 	value = redis_client.get(query).decode()
# 	print("Value is: {}".format(value))
# 	if value != None:
# 		print("Key exists")
# 		return value
# 	else:
# 		print("Key doesn't exist")
# 		return "They key does not exist"

def get_all_in_redis():
  # Just make sure things get mapped correctly from key -> value during testing
  all_keys = [key.decode() for key in redis_client.keys('*')]
  all_values = [value.decode() for value in redis_client.mget(all_keys)]
  key_values = dict(zip(all_keys, all_values))
  # for key in all_keys:
  #   print(f'key: {key} type: {type(key)}')
  #   if type(key) == 'string':
  #     key_values.append({key: redis_client.get(key)})
  return key_values


def main():
	parser = argparse.ArgumentParser(prog='vsock-sample')
	parser.add_argument("--version", action="version",
						help="Prints version information.",
						version='%(prog)s 0.1.0')
	subparsers = parser.add_subparsers(title="options")

	server_parser = subparsers.add_parser("server", description="Server",
										  help="Listen on a given port.")
	server_parser.add_argument("port", type=int, help="The local port to listen on.")
	server_parser.set_defaults(func=server_handler)
	
	if len(sys.argv) < 2:
		parser.print_usage()
		sys.exit(1)

	args = parser.parse_args()
	args.func(args)

if __name__ == "__main__":
	main()
