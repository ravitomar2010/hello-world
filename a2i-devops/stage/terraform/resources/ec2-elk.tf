############################## Security Group ####################################

module "elk_security_group" {
  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-elk-${local.environment}"
  description = "Security Group for elk"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["${local.variables[terraform.workspace].vpc_cidr}"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 9200
      to_port     = 9200
      protocol    = "tcp"
      description = "Ingress for Elastic API port  within VPC"
      cidr_blocks = "${var.stage_cidr},${var.prod_cidr},${var.old_prod_cidr}"
    },
    {
      from_port   = 9300
      to_port     = 9300
      protocol    = "tcp"
      description = "Ingress for Elastic node communication port  within VPC"
      cidr_blocks = "${var.stage_cidr},${var.prod_cidr},${var.old_prod_cidr}"
    },
    {
      from_port   = 5601
      to_port     = 5601
      protocol    = "tcp"
      description = "Ingress for Elastic node communication port  within VPC"
      cidr_blocks = "${var.stage_cidr},${var.prod_cidr},${var.old_prod_cidr}"
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

module "elk" {
  source = "../modules/terraform-aws-ec2-instance"

  instance_count = 1

  name                        = "elk"
  ami                         = data.aws_ami.ubuntu_bionic.id
  key_name                    = var.infra_private_keypair
  instance_type               = local.variables[terraform.workspace].ec2.elk.type
  associate_public_ip_address = false
  cpu_credits                 = "unlimited"
  subnet_id                   = tolist(module.vpc.infra_subnets)[0]
  vpc_security_group_ids      = [module.elk_security_group.this_security_group_id]
  iam_instance_profile        = "${aws_iam_instance_profile.elastic_profile.name}"
  tags                        = {
                                      "environment"           = "infra"
                                      "platform"              = "ubuntu"
                                      "application"           = "elk"
                                      "name"                  = "${var.platform}-elastic"
                                      "auto-stop-start"       = "false"
                                      "office-hours-instance" = "true"
                                }
}

############################## EBS Volumes ####################################

resource "aws_ebs_volume" "elk-first" {

  depends_on           	= [module.elk]
  availability_zone     = "${module.elk.availability_zone[0]}"
  size                  = 25
  type                  = "gp2"
  tags 			            = {
			                         Name	= "elk-first-ebs-storage"
  			                  }
}

resource "aws_volume_attachment" "elastic_att" {

  device_name   = "/dev/xvdb"
  volume_id     = "${aws_ebs_volume.elk-first.id}"
  instance_id   = "${module.elk.id[0]}"

}

############################## IAM ####################################

resource "aws_iam_instance_profile" "elastic_profile" {
  name = "elastic_profile"
  role = "${aws_iam_role.elastic_role.name}"
}

data "template_file" "elastic_assume_role_cfg" {
  template = "${file("${path.module}/templates/assumerole_ec2.tpl")}"
}

resource "aws_iam_role" "elastic_role" {
  name = "elastic_role"
  assume_role_policy = data.template_file.elastic_assume_role_cfg.rendered
  tags = {
    "Environment" = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "elastic_attach" {
  role       = "${aws_iam_role.elastic_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}


############################## Ansible ####################################

data "template_file" "elastic_ansible_role" {
  template = "${file("${path.module}/templates/elk.yml.tpl")}"
  vars = {
    aws_ec2_region = "${var.aws_region}"
    platform = "${var.platform}"
    environment = "${local.environment}"
    service_name : "${local.variables[terraform.workspace].ec2.elk.service_name}"
    dns_name_of_server : "${local.variables[terraform.workspace].ec2.elk.service_name}.${var.infra_dns}"
    zk_server_id       : "${local.variables[terraform.workspace].ec2.elk.zk_server_id}"
    env_dns            : "${local.variables[terraform.workspace].ec2.elk.env_dns}"
  }
}

resource "local_file" "elastic_roles" {
  depends_on = [ aws_eip.pritunl, module.elk ]
  content     = data.template_file.elastic_ansible_role.rendered
  filename = "${path.module}/../../ansible/plays/elk.yaml"
}


data "template_file" "elk_hosts" {
  template = "${file("${path.module}/templates/elk_hosts.tpl")}"
  vars = {
    elk_private_ip  =  module.elk.private_ip[0]
    private_pem_path          =  "${var.ec2_private_pem_path}${var.infra_private_keypair}.pem"
  }
}

resource "local_file" "elastic_inventory_file" {
  depends_on = [ aws_eip.pritunl, module.elk ]
  content     = data.template_file.elk_hosts.rendered
  filename = "${path.module}/../../ansible/hosts/elk_hosts"
}

resource "null_resource" "elastic_ansible" {
  depends_on = [ local_file.elastic_inventory_file, module.elk ]
  provisioner "local-exec" {
    command = "sleep 30;cd ${path.module}/../../ansible;ansible-playbook -i hosts/elk_hosts plays/elk.yaml"
  }
}


############################## Route 53 ####################################

resource "aws_route53_record" "elastic" {
  zone_id = "${data.aws_route53_zone.a2i-infra.zone_id}"
  name    = "${local.variables[terraform.workspace].ec2.elk.service_name}"
  type    = "A"
  ttl     = "300"
  records = ["${module.elk.private_ip[0]}"]
}

resource "aws_route53_record" "elasticsearch" {
  zone_id = "${data.aws_route53_zone.a2i-infra.zone_id}"
  name    = "elasticsearch"
  type    = "A"
  ttl     = "300"
  records = ["${module.elk.private_ip[0]}"]
}

resource "aws_route53_record" "kibana" {
  zone_id = "${data.aws_route53_zone.a2i-infra.zone_id}"
  name    = "kibana"
  type    = "A"
  ttl     = "300"
  records = ["${module.elk.private_ip[0]}"]
}

resource "aws_route53_record" "zk-3" {
  zone_id = "${data.aws_route53_zone.a2i-stage.zone_id}"
  name    = "zk-3"
  type    = "A"
  ttl     = "300"
  records = ["${module.elk.private_ip[0]}"]
}

resource "aws_route53_record" "zkookeeper" {
  zone_id = "${data.aws_route53_zone.a2i-stage.zone_id}"
  name    = "zk"
  type    = "A"
  ttl     = "300"
  records = ["${module.elk.private_ip[0]}","${module.infra_tools.private_ip[0]}","${module.prometheus.private_ip[0]}"]
}
