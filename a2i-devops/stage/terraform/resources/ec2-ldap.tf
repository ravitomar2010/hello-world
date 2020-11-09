############################## Security Group ####################################

module "ldap_server_security_group" {
  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-ldap-${local.environment}"
  description = "Security Group for ldap_server"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["${local.variables[terraform.workspace].vpc_cidr}"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      description = "Ingress for Elastic API port from withing VPC"
      cidr_blocks = "${var.office_cidr},${var.prod_cidr},${var.old_prod_cidr}"
    },
    {
      from_port   = 389
      to_port     = 389
      protocol    = "tcp"
      description = "Ingress for Elastic API port from withing VPC"
      cidr_blocks = "${var.office_cidr},${var.prod_cidr},${var.old_prod_cidr}"
    },
    {
      from_port   = 636
      to_port     = 636
      protocol    = "tcp"
      description = "Ingress for Elastic API port from withing VPC"
      cidr_blocks = "${var.office_cidr},${var.prod_cidr},${var.old_prod_cidr}"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "Ingress for SSH to ldap_server from within A2i"
      cidr_blocks = "${var.office_cidr},${var.prod_cidr},${var.old_prod_cidr}"
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


############################## Ec2 Instance ####################################

module "ldap_server" {

  source = "../modules/terraform-aws-ec2-instance"

  instance_count = 1

  name                        = "ldap_server"
  ami                         = data.aws_ami.ubuntu_xenial.id
  key_name                    = var.infra_private_keypair
  instance_type               = local.variables[terraform.workspace].ec2.ldap_server.type
  associate_public_ip_address = false
  cpu_credits                 = "unlimited"
  subnet_id                   = tolist(module.vpc.infra_subnets)[0]
  vpc_security_group_ids      = [module.ldap_server_security_group.this_security_group_id]
  iam_instance_profile        = "${aws_iam_instance_profile.ldap_server_profile.name}"

  tags                        =  {
                                      "Environment"     = "infra"
                                      "Application"     = "ldap_server"
                                      "Name"            = "${var.platform}-ldap_server"
                                      "auto-stop-start" = "false"
                                 }

}

############################## EBS Volumes ####################################

#resource "aws_ebs_volume" "ldap-first" {
#  depends_on           	= [module.ldap_server]
#  availability_zone     = "${module.ldap_server.availability_zone[0]}"
#  size                  = 5
#  type                  = "gp2"
#  tags 			            = {
#			                         Name	= "ldap_server-first-ebs-storage"
#  			                  }
#}
#resource "aws_volume_attachment" "ldap_att" {
#  device_name   = "/dev/xvdb"
#  volume_id     = "${aws_ebs_volume.ldap-first.id}"
#  instance_id   = "${module.ldap_server.id[0]}"
#}

##############################      IAM     ####################################

data "template_file" "ldap_server_assume_role_cfg" {
  template = "${file("${path.module}/templates/assumerole_ec2.tpl")}"
}

resource "aws_iam_instance_profile" "ldap_server_profile" {
  name = "ldap_server_profile"
  role = "${aws_iam_role.ldap_server_role.name}"
}

resource "aws_iam_role" "ldap_server_role" {
  name = "ldap_server_role"
  assume_role_policy = data.template_file.ldap_server_assume_role_cfg.rendered
  tags = {
    "Environment" = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "ldap_server_attach" {
  role       = "${aws_iam_role.ldap_server_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

############################## Ansible ####################################


data "template_file" "ldap_server_ansible_role" {
  template = "${file("${path.module}/templates/ldap_server.yml.tpl")}"
  vars = {
    openldap_server_domain_name = "${local.variables[terraform.workspace].ec2.ldap_server.openldap_server_domain_name}"
    ldap_dn = "${local.variables[terraform.workspace].ec2.ldap_server.ldap_dn}"
    openldap_server_rootuserpath_ssm = "${local.variables[terraform.workspace].ec2.ldap_server.openldap_server_rootuserpath_ssm}"
    service_name       = "${local.variables[terraform.workspace].ec2.ldap_server.service_name}"
    dns_name_of_server = "${local.variables[terraform.workspace].ec2.ldap_server.service_name}.${var.infra_dns}"
  }
}

resource "local_file" "ldap_server_roles" {
  depends_on = [ aws_eip.pritunl, module.pritunl, local_file.ssh_cfg ]
  content     = data.template_file.ldap_server_ansible_role.rendered
  filename = "${path.module}/../../ansible/plays/ldap_server.yaml"
}

data "template_file" "ldap_server_hosts" {
  template = "${file("${path.module}/templates/ldap_server_hosts.tpl")}"
  vars = {
    ldap_server_private_ip  =  module.ldap_server.private_ip[0]
    private_pem_path        =  "${var.ec2_private_pem_path}${var.infra_private_keypair}.pem"
  }
}

resource "local_file" "ldap_server_inventory_file" {
  depends_on = [ aws_eip.pritunl, module.ldap_server ]
  content     = data.template_file.ldap_server_hosts.rendered
  filename = "${path.module}/../../ansible/hosts/ldap_server_hosts"
}

resource "null_resource" "ldap_server_ansible" {
  depends_on = [ local_file.ldap_server_inventory_file, aws_eip.pritunl, module.ldap_server ]
  provisioner "local-exec" {
    command = "sleep 30;cd ${path.module}/../../ansible;ansible-playbook -i hosts/ldap_server_hosts plays/ldap_server.yaml"
  }
}


############################## Route 53 ####################################

resource "aws_route53_record" "ldap" {
  zone_id = "${data.aws_route53_zone.a2i-infra.zone_id}"
  name    = "${local.variables[terraform.workspace].ec2.ldap_server.service_name}"
  type    = "A"
  ttl     = "300"
  records = ["${module.ldap_server.private_ip[0]}"]
}
