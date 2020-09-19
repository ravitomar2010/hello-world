############################## Security Group ####################################

module "prometheus_security_group" {
  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-prometheus-${local.environment}"
  description = "Security Group for prometheus"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["${local.variables[terraform.workspace].vpc_cidr}"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      description = "Ingress for Elastic API port from withing VPC"
      cidr_blocks = "${var.office_cidr},${var.prod_cidr}"
    },
    {
      from_port   = 9090
      to_port     = 9095
      protocol    = "tcp"
      description = "Ingress for prometheus server services within VPC"
      cidr_blocks = "${var.office_cidr},${var.prod_cidr}"
    },
    {
      from_port   = 9100
      to_port     = 9600
      protocol    = "tcp"
      description = "Ingress for exporter server services within VPC"
      cidr_blocks = "${var.office_cidr},${var.prod_cidr}"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "Ingress for SSH to prometheus from within A2i"
      cidr_blocks = "${var.office_cidr},${var.prod_cidr}"
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

module "prometheus" {

  source = "../modules/terraform-aws-ec2-instance"

  instance_count = 1

  name                        = "prometheus"
  ami                         = data.aws_ami.ubuntu_xenial.id
  key_name                    = var.infra_private_keypair
  instance_type               = local.variables[terraform.workspace].ec2.prometheus.type
  associate_public_ip_address = false
  cpu_credits                 = "unlimited"
  subnet_id                   = tolist(module.vpc.infra_subnets)[0]
  vpc_security_group_ids      = [module.prometheus_security_group.this_security_group_id]
  iam_instance_profile        = "${aws_iam_instance_profile.prometheus_profile.name}"

  tags                        =  {
                                      "Environment"     = "infra"
                                      "Application"     = "prometheus"
                                      "Name"            = "${var.platform}-prometheus-${local.environment}"
                                      "auto-stop-start" = "false"
                                 }

}

############################## EBS Volumes ####################################

#resource "aws_ebs_volume" "prometheus-first" {
#  depends_on           	= [module.prometheus]
#  availability_zone     = "${module.prometheus.availability_zone[0]}"
#  size                  = 5
#  type                  = "gp2"
#  tags 			            = {
#			                         Name	= "prometheus-first-ebs-storage"
#  			                  }
#}
#resource "aws_volume_attachment" "prometheus_att" {
#  device_name   = "/dev/xvdb"
#  volume_id     = "${aws_ebs_volume.prometheus-first.id}"
#  instance_id   = "${module.prometheus.id[0]}"
#}

##############################      IAM     ####################################

data "template_file" "prometheus_assume_role_cfg" {
  template = "${file("${path.module}/templates/assumerole_ec2.tpl")}"
}

resource "aws_iam_instance_profile" "prometheus_profile" {
  name = "prometheus_profile"
  role = "${aws_iam_role.prometheus_role.name}"
}

resource "aws_iam_role" "prometheus_role" {
  name = "prometheus_role"
  assume_role_policy = data.template_file.prometheus_assume_role_cfg.rendered
  tags = {
    "Environment" = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "prometheus_attach" {
  role       = "${aws_iam_role.prometheus_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

############################## Ansible ####################################


data "template_file" "prometheus_ansible_role" {
  template = "${file("${path.module}/templates/prometheus.yml.tpl")}"
  vars = {
    service_name       : "${local.variables[terraform.workspace].ec2.prometheus.service_name}"
    dns_name_of_server : "${local.variables[terraform.workspace].ec2.prometheus.service_name}.${var.infra_dns}"
    zk_server_id       : "${local.variables[terraform.workspace].ec2.prometheus.zk_server_id}"
    env_dns            : "${local.variables[terraform.workspace].ec2.prometheus.env_dns}"
  }
}

resource "local_file" "prometheus_roles" {
  depends_on = [ aws_eip.pritunl, module.pritunl, local_file.ssh_cfg ]
  content     = data.template_file.prometheus_ansible_role.rendered
  filename = "${path.module}/../../ansible/plays/prometheus.yaml"
}

data "template_file" "prometheus_hosts" {
  template = "${file("${path.module}/templates/prometheus_hosts.tpl")}"
  vars = {
    prometheus_private_ip  =  module.prometheus.private_ip[0]
    private_pem_path  =  "${var.ec2_private_pem_path}${var.infra_private_keypair}.pem"
  }
}

resource "local_file" "prometheus_inventory_file" {
  depends_on = [ aws_eip.pritunl, module.prometheus ]
  content     = data.template_file.prometheus_hosts.rendered
  filename = "${path.module}/../../ansible/hosts/prometheus_hosts"
}

resource "null_resource" "prometheus_ansible" {
  depends_on = [ local_file.prometheus_inventory_file, aws_eip.pritunl, module.prometheus ]
  provisioner "local-exec" {
    command = "sleep 30;cd ${path.module}/../../ansible;ansible-playbook -i hosts/prometheus_hosts plays/prometheus.yaml"
  }
}


############################## Route 53 ####################################

resource "aws_route53_record" "prometheus" {
  zone_id = "${data.aws_route53_zone.a2i-infra.zone_id}"
  name    = "${local.variables[terraform.workspace].ec2.prometheus.service_name}"
  type    = "A"
  ttl     = "300"
  records = ["${module.prometheus.private_ip[0]}"]
}

resource "aws_route53_record" "zk-2" {
  zone_id = "${data.aws_route53_zone.a2i-stage.zone_id}"
  name    = "zk-2"
  type    = "A"
  ttl     = "300"
  records = ["${module.prometheus.private_ip[0]}"]
}
