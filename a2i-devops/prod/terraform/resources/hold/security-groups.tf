############################## Security Group for ssh ####################################

module "ssh_security_group" {
  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-ssh-${local.environment}"
  description = "Security Group to allow ssh access to instances"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["${local.variables[terraform.workspace].vpc_cidr}"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "Ingress for SSH only from the terraform workstation"
      cidr_blocks = "${var.office_cidr},${var.stage_cidr},${var.prod_cidr}"
    },
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "Allowed all traffic from workstation"
      cidr_blocks = "${chomp(data.http.myip.body)}/32,${var.stage_cidr}"
    },
  ]
  egress_rules        = ["all-all"]
}

############################## Security Group for lambda ####################################

module "lambda_security_group" {
  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-lambda-${local.environment}"
  description = "Security Group to allow ssh access to instances"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["${local.variables[terraform.workspace].vpc_cidr}"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "Allowed all traffic from workstation"
      cidr_blocks = "${chomp(data.http.myip.body)}/32,${var.stage_cidr},${var.prod_cidr},${var.office_cidr}"
    },
  ]
  egress_rules        = ["all-all"]
}

############################## Security Group for Redshift ####################################

module "redshift_security_group" {
  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-redshift-${local.environment}"
  description = "Security Group to allow access to redshift"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["${local.variables[terraform.workspace].vpc_cidr}"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "Allowed all traffic from workstation"
      cidr_blocks = "${chomp(data.http.myip.body)}/32,${var.stage_cidr},${var.prod_cidr}"
    },
  ]
  egress_rules        = ["all-all"]
}

############################## Security Group for Route53 Resolver ####################################

module "r53_resolver_security_group" {
  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-r53-resolver-${local.environment}"
  description = "Security Group to allow access to redshift"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["${local.variables[terraform.workspace].vpc_cidr}"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "Allowed all traffic from workstation"
      cidr_blocks = "${chomp(data.http.myip.body)}/32,${var.stage_cidr},${var.prod_cidr},${var.office_cidr}"
    },
  ]
  egress_rules        = ["all-all"]
}
