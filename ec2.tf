# Once Terraform accepts ssm parameters as the image_id for launch templates, this can be removed
data "aws_ssm_parameter" "ami_id" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

resource "aws_security_group" "allow_web" {
	name_prefix = "allow_web_enclave_"
	description = "Allow web requests to enclave server"
	vpc_id      = var.vpc_id

	ingress {
		description      = "TLS from anywhere"
		from_port        = 443
		to_port          = 443
		protocol         = "tcp"
		cidr_blocks      = ["0.0.0.0/0"]
	}
	
	ingress {
		description      = "${local.server_port} from anywhere"
		from_port        = local.server_port
		to_port          = local.server_port
		protocol         = "tcp"
		cidr_blocks      = ["0.0.0.0/0"]
	}

	egress {
		from_port        = 0
		to_port          = 0
		protocol         = "-1"
		cidr_blocks      = ["0.0.0.0/0"]
	}

	tags = {
		Name = "allow_web_enclave"
	}
}

resource "aws_launch_template" "enclave_lt" {
	name_prefix = "enclave_ec2"

	block_device_mappings {
		device_name = "/dev/sda1"

		ebs {
			volume_size = 20
		}
	}
	
	block_device_mappings {
		device_name = local.volume_mount

		ebs {
			volume_size = 10
			delete_on_termination = true
			encrypted = true
		}
	}
	
	ebs_optimized = true

	iam_instance_profile {
		name = aws_iam_instance_profile.admin_profile.name
	}

	# This should eventually be replaced with an ssm parameter
	image_id = data.aws_ssm_parameter.ami_id.value

	instance_initiated_shutdown_behavior = "terminate"

	instance_type = "m5.xlarge"

	network_interfaces {
		associate_public_ip_address = true
		security_groups   = [
			aws_security_group.allow_web.id
		]
	}

	tag_specifications {
		resource_type = "instance"

		tags = {
			Name = "enclave-instance"
		}
	}
	
	enclave_options {
		enabled = true
	}
	
	user_data = base64encode(data.template_file.user_data.rendered)

}

data "template_file" "user_data" {
	template = "${file("${path.module}/run.sh.tpl")}"
	vars = {
		s3_bucket        = aws_s3_bucket.bucket.id
		s3_prefix        = local.s3_prefix
		volume_mount     = local.volume_mount
		nitro_lookup_dir = local.nitro_lookup_dir
	}
}

resource "aws_instance" "enclave_instance" {
	launch_template {
		id      = aws_launch_template.enclave_lt.id
		version = "$Latest"
	}
	
	subnet_id = var.subnet_ids[0]
	
	tags = {
		Name = "Enclave Test"
	}
	
	user_data = data.template_file.user_data.rendered
	
	user_data_replace_on_change = true
	
	depends_on = [
		aws_s3_object.enclave_files
	]
	
	lifecycle {
		create_before_destroy = true
		
		replace_triggered_by = [
			aws_s3_object.enclave_files
		]
	}
}