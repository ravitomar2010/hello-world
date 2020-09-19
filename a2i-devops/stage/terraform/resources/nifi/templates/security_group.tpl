############################## ########### #################################### 
############################ Security Groups ##################################
############################## ########### ####################################

module "nifi_security_group" {
  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-nifi-${local.environment}"
  description = "Security Group for nifi"
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
