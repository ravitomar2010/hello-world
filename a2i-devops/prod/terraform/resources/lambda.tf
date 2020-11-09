############################## Security Group ####################################

module "lambda_security_group" {

  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-lambda-${local.environment}"
  description = "Security Group for lambda"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["${local.variables[terraform.workspace].vpc_cidr}"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "Allowed all traffic from workstation"
      cidr_blocks = "${var.prod_cidr},${var.office_cidr},${var.prod_cidr_old}"
    },

  ]
  egress_rules        = ["all-all"]
}

############################## IAM ####################################

resource "aws_iam_instance_profile" "lambda_profile" {
  name = "lambda_profile"
  role = "${aws_iam_role.lambda_role.name}"
}

data "template_file" "lambda_assume_role_cfg" {
  template = "${file("${path.module}/templates/assumerole_lambda.tpl")}"
}

resource "aws_iam_role" "lambda_role" {
  name = "a2i-lambda-role"
  assume_role_policy = data.template_file.lambda_assume_role_cfg.rendered
  tags = {
    "Environment" = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "lambda_attach_s3" {
  role       = "${aws_iam_role.lambda_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_attach_ses" {
  role       = "${aws_iam_role.lambda_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_attach_ssm" {
  role       = "${aws_iam_role.lambda_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole"
}

resource "aws_iam_role_policy_attachment" "lambda_attach_executeAccess" {
  role       = "${aws_iam_role.lambda_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_attach_xray" {
  role       = "${aws_iam_role.lambda_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_attach_vpcAccess" {
  role       = "${aws_iam_role.lambda_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_attach_sns" {
  role       = "${aws_iam_role.lambda_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_attach_sf" {
  role       = "${aws_iam_role.lambda_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSStepFunctionsFullAccess"
}
