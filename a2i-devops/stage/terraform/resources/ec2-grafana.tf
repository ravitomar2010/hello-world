############################## Security Group ####################################

module "grafana_security_group" {

  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-grafana-${local.environment}"
  description = "Security Group for grafana"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["${local.variables[terraform.workspace].vpc_cidr}"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "Allowed all traffic from workstation"
      cidr_blocks = "${chomp(data.http.myip.body)}/32,${var.stage_cidr},${var.prod_cidr},${var.office_cidr},${var.old_prod_cidr}"
    },
  ]
  egress_rules        = ["all-all"]
}

############################## Ec2 Instance ####################################

module "grafana" {
  source = "../modules/terraform-aws-ec2-instance"

  instance_count = 1

  name                        = "grafana"
  ami                         = data.aws_ami.ubuntu_bionic.id
  key_name                    = var.infra_private_keypair
  instance_type               = local.variables[terraform.workspace].ec2.grafana.type
  associate_public_ip_address = false
  cpu_credits                 = "unlimited"
  subnet_id                   = tolist(module.vpc.infra_subnets)[0]
  vpc_security_group_ids      = [module.grafana_security_group.this_security_group_id]
  iam_instance_profile        = "${aws_iam_instance_profile.grafana_profile.name}"
  tags = {
    "environment"             = local.environment
    "platform"                = "ubuntu"
    "application"             = "grafana"
    "name"                    = "${var.platform}-grafana"
    "office-hours-instance"   = "true"
  }
}

############################## EBS Volumes ####################################

resource "aws_ebs_volume" "grafana-first" {

  depends_on           	= [module.grafana]
  availability_zone     = "${module.grafana.availability_zone[0]}"
  size                  = 1
  type                  = "gp2"
  tags 			            = {
			                         Name	= "grafana-first-ebs-storage"
  			                  }
}

resource "aws_volume_attachment" "grafana_att" {

  device_name   = "/dev/xvdb"
  volume_id     = "${aws_ebs_volume.grafana-first.id}"
  instance_id   = "${module.grafana.id[0]}"

}

############################## IAM ####################################

resource "aws_iam_instance_profile" "grafana_profile" {
  name = "grafana_profile"
  role = "${aws_iam_role.grafana_role.name}"
}

data "template_file" "grafana_assume_role_cfg" {
  template = "${file("${path.module}/templates/assumerole_ec2.tpl")}"
}

resource "aws_iam_role" "grafana_role" {
  name = "grafana_role"
  assume_role_policy = data.template_file.grafana_assume_role_cfg.rendered
  tags = {
    "Environment" = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "grafana_attach_ec2" {
  role       = "${aws_iam_role.grafana_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "grafana_attach_s3" {
  role       = "${aws_iam_role.grafana_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

############################## Ansible ####################################

data "template_file" "grafana_ansible_role" {
  template = "${file("${path.module}/templates/grafana.yml.tpl")}"
  vars = {
    service_name : "${local.variables[terraform.workspace].ec2.grafana.service_name}"
    dns_name_of_server : "${local.variables[terraform.workspace].ec2.grafana.service_name}.${var.infra_dns}"
    grafana_server_rootdbuserpath_ssm: "${local.variables[terraform.workspace].ec2.grafana.grafana_server_rootdbuserpath_ssm}"
    }
}

resource "local_file" "grafana_roles" {
  depends_on = [ aws_eip.pritunl, module.pritunl, local_file.ssh_cfg ]
  content     = data.template_file.grafana_ansible_role.rendered
  filename = "${path.module}/../../ansible/plays/grafana.yaml"
}

data "template_file" "grafana_hosts" {
  template = "${file("${path.module}/templates/grafana_hosts.tpl")}"
  vars = {
    grafana_private_ip  =  module.grafana.private_ip[0]
    private_pem_path  =  var.ec2_private_pem_path
  }
}

resource "local_file" "grafana_inventory_file" {
    depends_on = [ aws_eip.pritunl, module.grafana ]
    content     = data.template_file.grafana_hosts.rendered
    filename = "${path.module}/../../ansible/hosts/grafana_hosts"
}

resource "null_resource" "grafana_ansible" {
  depends_on = [ local_file.grafana_inventory_file, aws_eip.pritunl, module.grafana ]
  provisioner "local-exec" {
    command = "sleep 30;cd ${path.module}/../../ansible;ansible-playbook -i hosts/grafana_hosts plays/grafana.yaml"
  }
}
############################## Route 53 ####################################

resource "aws_route53_record" "grafana" {
  zone_id = "${data.aws_route53_zone.a2i-infra.zone_id}"
  name    = "${local.variables[terraform.workspace].ec2.grafana.service_name}"
  type    = "A"
  ttl     = "300"
  records = ["${module.grafana.private_ip[0]}"]
}
