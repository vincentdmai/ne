#!/usr/bin/env python

import argparse
import http.server
import os
import enclave_client
import base64
import subprocess
import json

output = subprocess.check_output(['nitro-cli', 'describe-enclaves'])
enclaves = json.loads(output)

# Get the EnclaveCID of the first enclave
enclave_cid = enclaves[0]['EnclaveCID']

# Print the EnclaveCID
print(enclave_cid)

class HTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_PUT(self):
        path = self.translate_path(self.path)
        length = int(self.headers['Content-Length'])
        query = json.dumps({'set': json.loads(self.rfile.read(length).decode())}).encode()
        print(query)
        query64 = base64.b64encode(query)
        print(query64)
        args = argparse.Namespace(cid=enclave_cid, port=5005, query=query64.decode())
        output = enclave_client.client_handler(args)
        self.send_response(201)
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        message = "Created".encode()
        self.wfile.write(message)
    def do_GET(self):
        path = self.path.split('/')[1]
        query = json.dumps({'get': path}).encode()
        print(query)
        query64 = base64.b64encode(query)
        print(query64)
        args = argparse.Namespace(cid=enclave_cid, port=5005, query=query64.decode())
        output = enclave_client.client_handler(args)
        print("Output: {}".format(output))
        self.send_response(200)
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        message = output.encode()
        self.wfile.write(message)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--bind', '-b', default='0.0.0.0', metavar='ADDRESS',
                        help='Specify alternate bind address '
                             '[default: all interfaces]')
    parser.add_argument('port', action='store',
                        default=8000, type=int,
                        nargs='?',
                        help='Specify alternate port [default: 8000]')
    args = parser.parse_args()

    http.server.test(HandlerClass=HTTPRequestHandler, port=args.port, bind=args.bind)
