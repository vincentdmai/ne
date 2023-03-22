# // Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# // SPDX-License-Identifier: MIT-0
import argparse
import socket
import sys
import json
import urllib.request
import redis
import base64
import re

r = redis.Redis(unix_socket_path='/run/redis.sock')
for i in range(1,100):
	r.set('foo{}'.format(i), 'bar{}'.format(i))

# Running server you have pass port the server  will listen to. For Example:
# $ python3 /app/server.py server 5005
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
				print("Let's accept stuff")
				(from_client, (remote_cid, remote_port)) = self.sock.accept()
				print("Connection from " + str(from_client) + str(remote_cid) + str(remote_port))
				
				query = json.loads(base64.b64decode(from_client.recv(1024).decode()).decode())
				print("Message received: {}".format(query))
				query_type = list(query.keys())[0]
				query = query[query_type]
				
				print("{} {}".format(query_type, query))
				if query_type == 'get':
					response = query_redis(query)
				elif query_type == 'set':
					response = put_in_redis(query)
				else:
					response = "Bad query type"
				
				# Send back the response                 
				from_client.send(str(response).encode())
	
				from_client.close()
				print("Client call closed")
			except Exception as ex:
				print(ex)

def server_handler(args):
	server = VsockListener()
	server.bind(args.port)
	print("Started listening to port : ",str(args.port))
	server.recv_data()

def put_in_redis(query):
	for key in query.keys():
		value = query[key]
		r.set(key, value)
		print("Setting {} to {}".format(key, value))
	return "Put the data in"

# Get list of current ip ranges for the S3 service for a region.
# Learn more here: https://docs.aws.amazon.com/general/latest/gr/aws-ip-ranges.html#aws-ip-download 
def query_redis(query):
	value = r.get(query)
	print("Value is: {}".format(value))
	if value != None:
		print("Key exists")
		return "The key exists"
	elif value == None:
		print("Key doesn't exist")
		return "They key does not exist"
	else:
		print("In Else")
		return "Somehow here with value: {}".format(value)


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
