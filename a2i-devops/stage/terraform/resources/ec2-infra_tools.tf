############################## Security Group ####################################

module "infra_tools_security_group" {

  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-infra_tools-${local.environment}"
  description = "Security Group for infra_tools"
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

############################## Ec2 Instance ####################################

module "infra_tools" {
  source = "../modules/terraform-aws-ec2-instance"

  instance_count = 1

  name                        = "infra_tools"
  ami                         = data.aws_ami.ubuntu_bionic.id
  key_name                    = var.infra_private_keypair
  instance_type               = local.variables[terraform.workspace].ec2.infra_tools.type
  associate_public_ip_address = false
  cpu_credits                 = "unlimited"
  subnet_id                   = tolist(module.vpc.infra_subnets)[0]
  vpc_security_group_ids      = [module.infra_tools_security_group.this_security_group_id]
  iam_instance_profile        = "${aws_iam_instance_profile.infra_tools_profile.name}"
  tags = {
    "environment"             = local.environment
    "platform"                = "ubuntu"
    "application"             = "infra_tools"
    "name"                    = "${var.platform}-infra_tools-${local.environment}"
    "office-hours-instance"   = "true"
  }
}

############################## EBS Volumes ####################################

#resource "aws_ebs_volume" "infra_tools-first" {
#  depends_on           	= [module.infra_tools]
#  availability_zone     = "${module.infra_tools.availability_zone[0]}"
#  size                  = 1
#  type                  = "gp2"
#  tags 			            = {
#			                         Name	= "infra_tools-first-ebs-storage"
#  			                  }
#}
#resource "aws_volume_attachment" "infra_tools_att" {
#  device_name   = "/dev/xvdb"
#  volume_id     = "${aws_ebs_volume.infra_tools-first.id}"
#  instance_id   = "${module.infra_tools.id[0]}"
#}

############################## IAM ####################################

resource "aws_iam_instance_profile" "infra_tools_profile" {
  name = "infra_tools_profile"
  role = "${aws_iam_role.infra_tools_role.name}"
}

data "template_file" "infra_tools_assume_role_cfg" {
  template = "${file("${path.module}/templates/assumerole_ec2.tpl")}"
}

resource "aws_iam_role" "infra_tools_role" {
  name = "infra_tools_role"
  assume_role_policy = data.template_file.infra_tools_assume_role_cfg.rendered
  tags = {
    "Environment" = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "infra_tools_attach" {
  role       = "${aws_iam_role.infra_tools_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

############################## Ansible ####################################

data "template_file" "infra_tools_ansible_role" {
  template = "${file("${path.module}/templates/infra_tools.yml.tpl")}"
  vars = {
    service_name        : "${local.variables[terraform.workspace].ec2.infra_tools.service_name}"
    zk_server_id        : "${local.variables[terraform.workspace].ec2.infra_tools.zk_server_id}"
    env_dns             : "${local.variables[terraform.workspace].ec2.infra_tools.env_dns}"
    is_ca_server        : "${local.variables[terraform.workspace].ec2.infra_tools.is_ca_server}"
    ca_server_dn        : "${local.variables[terraform.workspace].ec2.infra_tools.ca_server_dn}"
    ca_server_hostname  : "${local.variables[terraform.workspace].ec2.infra_tools.ca_server_hostname}"
    dns_name_of_server  : "${local.variables[terraform.workspace].ec2.infra_tools.dns_name_of_server}"
    }
}

resource "local_file" "infra_tools_roles" {
  depends_on = [ aws_eip.pritunl, module.pritunl, local_file.ssh_cfg ]
  content     = data.template_file.infra_tools_ansible_role.rendered
  filename = "${path.module}/../../ansible/plays/infra_tools.yaml"
}

data "template_file" "infra_tools_hosts" {
  template = "${file("${path.module}/templates/infra_tools_hosts.tpl")}"
  vars = {
    infra_tools_private_ip  =  module.infra_tools.private_ip[0]
    private_pem_path  =  "${var.ec2_private_pem_path}${var.infra_private_keypair}.pem"
  }
}

resource "local_file" "infra_tools_inventory_file" {
    depends_on = [ aws_eip.pritunl, module.infra_tools ]
    content     = data.template_file.infra_tools_hosts.rendered
    filename = "${path.module}/../../ansible/hosts/infra_tools_hosts"
}

resource "null_resource" "infra_tools_ansible" {
  depends_on = [ local_file.infra_tools_inventory_file, aws_eip.pritunl, module.infra_tools ]
  provisioner "local-exec" {
    command = "sleep 30;cd ${path.module}/../../ansible;ansible-playbook -i hosts/infra_tools_hosts plays/infra_tools.yaml"
  }
}
############################## Route 53 ####################################

resource "aws_route53_record" "infra_tools" {
  zone_id = "${data.aws_route53_zone.a2i-infra.zone_id}"
  name    = "${local.variables[terraform.workspace].ec2.infra_tools.service_name}"
  type    = "A"
  ttl     = "300"
  records = ["${module.infra_tools.private_ip[0]}"]
}

resource "aws_route53_record" "ca-server" {
  zone_id = "${data.aws_route53_zone.a2i-infra.zone_id}"
  name    = "ca-server"
  type    = "A"
  ttl     = "300"
  records = ["${module.infra_tools.private_ip[0]}"]
}

resource "aws_route53_record" "zk-1" {
  zone_id = "${data.aws_route53_zone.a2i-stage.zone_id}"
  name    = "zk-1"
  type    = "A"
  ttl     = "300"
  records = ["${module.infra_tools.private_ip[0]}"]
}
