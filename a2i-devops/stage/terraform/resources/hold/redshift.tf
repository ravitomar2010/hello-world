
############################## Security Group ####################################

module "redshift_security_group" {
  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-redshift-${local.environment}-"
  description = "Security Group for Redshift"
  vpc_id      = module.vpc.vpc_id

#  ingress_cidr_blocks = ["${local.variables[prod].vpc_cidr}"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "Allowed all traffic from workstation"
      cidr_blocks = "${chomp(data.http.myip.body)}/32,${var.stage_cidr},${var.prod_cidr},${var.office_cidr}"
    }
  ]

  egress_rules        = ["all-all"]
}

############################## Redshift ####################################

module "redshift" {
  source = "../modules/terraform-aws-redshift"

  cluster_identifier      = "${var.platform}-redshift-${local.environment}"
  cluster_node_type       = "dc2.large"
  cluster_number_of_nodes = 1

  cluster_database_name   = "axiom_rnd"
  cluster_master_username = "axiom_rnd"
  cluster_master_password = "4p_WkM$%MsYR"

  subnets                     = module.vpc.database_subnets
  vpc_security_group_ids      = [module.redshift_security_group.this_security_group_id]
  redshift_subnet_group_name  = module.vpc.redshift_subnet_group
}



######################### Route 53 for main redshift url #################################

resource "aws_route53_record" "rs-stage" {
  zone_id = "${aws_route53_zone.a2i-stage.zone_id}"
  name    = "axiom-dwh"
  type    = "CNAME"
  ttl     = "300"
  records = [ "${module.redshift.this_redshift_cluster_hostname}" ]
}
