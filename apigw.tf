resource "aws_api_gateway_rest_api" "api" {
	name = var.enclave_api_name
}

resource "aws_api_gateway_method" "root_put_method" {
	authorization = "NONE"
	http_method   = "PUT"
	resource_id   = aws_api_gateway_rest_api.api.root_resource_id
	rest_api_id   = aws_api_gateway_rest_api.api.id
	request_parameters   = {
		"method.request.header.content-type" = false
	}
}

resource "aws_api_gateway_integration" "root_put_int" {
	rest_api_id = aws_api_gateway_rest_api.api.id
	resource_id = aws_api_gateway_rest_api.api.root_resource_id
	http_method = aws_api_gateway_method.root_put_method.http_method

	request_parameters = {
		"integration.request.header.content-type" = "method.request.header.content-type"
	}

	type                    = "HTTP"
	uri                     = "http://${aws_instance.enclave_instance.public_ip}"
	integration_http_method = "PUT"
}

resource "aws_api_gateway_method_response" "root_put_method_response_200" {
	rest_api_id = aws_api_gateway_rest_api.api.id
	resource_id = aws_api_gateway_rest_api.api.root_resource_id
	http_method = aws_api_gateway_method.root_put_method.http_method
	status_code = "200"
	response_models     = {
		"application/json" = "Empty"
	}
	
	depends_on = [
		aws_api_gateway_integration.root_put_int,
		aws_api_gateway_method.root_put_method,
	]
}

resource "aws_api_gateway_integration_response" "root_put_int_response" {
	rest_api_id = aws_api_gateway_rest_api.api.id
	resource_id = aws_api_gateway_rest_api.api.root_resource_id
	http_method = aws_api_gateway_method.root_put_method.http_method
	status_code = aws_api_gateway_method_response.root_put_method_response_200.status_code
	
	depends_on = [
		aws_api_gateway_integration.root_put_int,
		aws_api_gateway_integration_response.root_put_int_response,
	]
}

resource "aws_api_gateway_resource" "key_resource" {
	parent_id   = aws_api_gateway_rest_api.api.root_resource_id
	path_part   = "{key}"
	rest_api_id = aws_api_gateway_rest_api.api.id
}

resource "aws_api_gateway_method" "key_get_method" {
	authorization = "NONE"
	http_method   = "GET"
	resource_id   = aws_api_gateway_resource.key_resource.id
	rest_api_id   = aws_api_gateway_rest_api.api.id
	
	request_parameters   = {
		"method.request.path.key" = true
	}
}

resource "aws_api_gateway_integration" "key_get_int" {
	rest_api_id = aws_api_gateway_rest_api.api.id
	resource_id = aws_api_gateway_resource.key_resource.id
	http_method = aws_api_gateway_method.key_get_method.http_method

	request_parameters = {
		"integration.request.path.key" = "method.request.path.key"
	}

	type                    = "HTTP"
	uri                     = "http://${aws_instance.enclave_instance.public_ip}/{key}"
	integration_http_method = "GET"
}

resource "aws_api_gateway_method_response" "key_get_method_response_200" {
	rest_api_id = aws_api_gateway_rest_api.api.id
	resource_id = aws_api_gateway_resource.key_resource.id
	http_method = aws_api_gateway_method.key_get_method.http_method
	status_code = "200"
	response_models     = {
		"application/json" = "Empty"
	}
	
	depends_on = [
		aws_api_gateway_integration.key_get_int,
		aws_api_gateway_method.key_get_method,
	]
}

resource "aws_api_gateway_integration_response" "key_get_int_response" {
	rest_api_id = aws_api_gateway_rest_api.api.id
	resource_id = aws_api_gateway_resource.key_resource.id
	http_method = aws_api_gateway_method.key_get_method.http_method
	status_code = aws_api_gateway_method_response.key_get_method_response_200.status_code
	
	depends_on = [
		aws_api_gateway_integration.key_get_int,
		aws_api_gateway_method.key_get_method,
	]
}

resource "aws_api_gateway_deployment" "deployment" {
	rest_api_id = aws_api_gateway_rest_api.api.id

	triggers = {
		# NOTE: The configuration below will satisfy ordering considerations,
		#       but not pick up all future REST API changes. More advanced patterns
		#       are possible, such as using the filesha1() function against the
		#       Terraform configuration file(s) or removing the .id references to
		#       calculate a hash against whole resources. Be aware that using whole
		#       resources will show a difference after the initial implementation.
		#       It will stabilize to only change when resources change afterwards.
		redeployment = sha1(jsonencode([
			aws_api_gateway_resource.key_resource.id,
			aws_api_gateway_method.key_get_method.id,
			aws_api_gateway_integration.key_get_int.uri,
			aws_api_gateway_method.root_put_method.id,
			aws_api_gateway_integration.root_put_int.uri,
		]))
	}

	lifecycle {
		create_before_destroy = true
	}
	
	depends_on = [
		aws_api_gateway_integration.key_get_int,
		aws_api_gateway_method.key_get_method,
		aws_api_gateway_integration.root_put_int,
		aws_api_gateway_method.root_put_method,
		aws_api_gateway_method_response.key_get_method_response_200,
		aws_api_gateway_method_response.root_put_method_response_200,
	]
}

resource "aws_api_gateway_stage" "stage" {
	deployment_id = aws_api_gateway_deployment.deployment.id
	rest_api_id   = aws_api_gateway_rest_api.api.id
	stage_name    = "deployment"
	
	depends_on = [
		aws_api_gateway_integration.key_get_int,
		aws_api_gateway_method.key_get_method,
		aws_api_gateway_integration.root_put_int,
		aws_api_gateway_method.root_put_method,
		aws_api_gateway_method_response.key_get_method_response_200,
		aws_api_gateway_method_response.root_put_method_response_200,
	]
}