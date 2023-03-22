data "aws_iam_policy_document" "instance_assume_role_policy" {
	statement {
		actions = ["sts:AssumeRole"]

		principals {
			type        = "Service"
			identifiers = ["ec2.amazonaws.com"]
		}
	}
}

data "aws_iam_policy" "admin_policy" {
	name = "AdministratorAccess"
}

resource "aws_iam_role" "admin_role" {
	name_prefix         = "EnclavePOCAdminRole"
	assume_role_policy  = data.aws_iam_policy_document.instance_assume_role_policy.json
	managed_policy_arns = [data.aws_iam_policy.admin_policy.arn]
}

resource "aws_iam_instance_profile" "admin_profile" {
	name_prefix = "EnclavePOCInstanceProfile"
	role = aws_iam_role.admin_role.name
}