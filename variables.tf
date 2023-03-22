variable "vpc_id" {
	type = string
}

variable "subnet_ids" {
	type = list(string)
}

variable "enclave_api_name" {
	type		= string
	default = "enclave-api"
}