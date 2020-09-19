############################## Security Group ####################################

module "kibana_security_group" {

  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-kibana-${local.environment}"
  description = "Security Group for Kibana"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["${local.variables[terraform.workspace].vpc_cidr}"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 5601
      to_port     = 5601
      protocol    = "tcp"
      description = "Ingress for Elastic API port from withing VPC"
      cidr_blocks = local.variables[terraform.workspace].vpc_cidr
    },
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

module "kibana" {
  source = "../modules/terraform-aws-ec2-instance"

  instance_count = 1

  name                        = "kibana"
  ami                         = data.aws_ami.ubuntu_bionic.id
  key_name                    = var.infra_private_keypair
  instance_type               = local.variables[terraform.workspace].ec2.kibana.type
  associate_public_ip_address = false
  cpu_credits                 = "unlimited"
  subnet_id                   = tolist(module.vpc.infra_subnets)[0]
  vpc_security_group_ids      = [module.kibana_security_group.this_security_group_id]
  iam_instance_profile        = "${aws_iam_instance_profile.kibana_profile.name}"
  tags = {
    "Environment"     = local.environment
    "Application"     = "Kibana"
    "Name"            = "${var.platform}-kibana-${local.environment}"
    "office-hours-instance" = "true"
  }
}

############################## EBS Volumes ####################################

resource "aws_ebs_volume" "kibana-first" {

  depends_on           	= [module.kibana]
  availability_zone     = "${module.kibana.availability_zone[0]}"
  size                  = 1
  type                  = "gp2"
  tags 			            = {
			                         Name	= "kibana-first-ebs-storage"
  			                  }
}

resource "aws_volume_attachment" "kibana_att" {

  device_name   = "/dev/xvdb"
  volume_id     = "${aws_ebs_volume.kibana-first.id}"
  instance_id   = "${module.kibana.id[0]}"

}

############################## IAM ####################################

resource "aws_iam_instance_profile" "kibana_profile" {
  name = "kibana_profile"
  role = "${aws_iam_role.kibana_role.name}"
}

data "template_file" "kibana_assume_role_cfg" {
  template = "${file("${path.module}/templates/assumerole_ec2.tpl")}"
}

resource "aws_iam_role" "kibana_role" {
  name = "kibana_role"
  assume_role_policy = data.template_file.kibana_assume_role_cfg.rendered
  tags = {
    "Environment" = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "kibana_attach" {
  role       = "${aws_iam_role.kibana_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

############################## Ansible ####################################

data "template_file" "kibana_ansible_role" {
  template = "${file("${path.module}/templates/kibana.yml.tpl")}"
  vars = {
    service_name : "${local.variables[terraform.workspace].ec2.kibana.service_name}"
    dns_name_of_server : "${local.variables[terraform.workspace].ec2.kibana.service_name}.${var.infra_dns}"
  }
}

resource "local_file" "kibana_roles" {
  depends_on = [ aws_eip.pritunl, module.pritunl, local_file.ssh_cfg ]
  content     = data.template_file.kibana_ansible_role.rendered
  filename = "${path.module}/../../ansible/plays/kibana.yaml"
}

data "template_file" "kibana_hosts" {
  template = "${file("${path.module}/templates/kibana_hosts.tpl")}"
  vars = {
    kibana_private_ip  =  module.kibana.private_ip[0]
    private_pem_path   =  "${var.ec2_private_pem_path}${var.infra_private_keypair}.pem"
  }
}

resource "local_file" "kibana_inventory_file" {
    depends_on = [ aws_eip.pritunl, module.kibana ]
    content     = data.template_file.kibana_hosts.rendered
    filename = "${path.module}/../../ansible/hosts/kibana_hosts"
}

resource "null_resource" "kibana_ansible" {
  depends_on = [ local_file.kibana_inventory_file, aws_eip.pritunl, module.kibana ]
  provisioner "local-exec" {
    command = "sleep 30;cd ${path.module}/../../ansible;ansible-playbook -i hosts/kibana_hosts plays/kibana.yaml"
  }
}
############################## Route 53 ####################################

resource "aws_route53_record" "kibana" {
  zone_id = "${aws_route53_zone.a2i-infra.zone_id}"
  name    = "${local.variables[terraform.workspace].ec2.kibana.service_name}"
  type    = "A"
  ttl     = "300"
  records = ["${module.kibana.private_ip[0]}"]
}
