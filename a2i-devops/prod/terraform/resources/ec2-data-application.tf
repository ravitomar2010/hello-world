############################## Security Group ####################################

module "data-application_security_group" {

  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-data-application-${local.environment}"
  description = "Security Group for data-application"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["${local.variables[terraform.workspace].vpc_cidr}"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "Allowed all traffic from workstation"
      cidr_blocks = "${chomp(data.http.myip.body)}/32,${var.stage_cidr},${var.prod_cidr},${var.office_cidr},${var.prod_cidr_old}"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "Ingress for SSH to ldap_server from within A2i"
      cidr_blocks = "${var.office_cidr},${var.prod_cidr}"
    },

  ]
  egress_rules        = ["all-all"]
}

############################## Ec2 Instance ####################################

module "data-application" {
  source = "../modules/terraform-aws-ec2-instance"

  instance_count = 1

  name                        = "data-application"
  ami                         = data.aws_ami.ubuntu_bionic.id
  key_name                    = var.prod_private_keypair
  instance_type               = local.variables[terraform.workspace].ec2.data-application.type
  associate_public_ip_address = false
  cpu_credits                 = "unlimited"
  subnet_id                   = tolist(module.vpc.private_subnets)[0]
  vpc_security_group_ids      = [module.data-application_security_group.this_security_group_id]
  iam_instance_profile        = "${aws_iam_instance_profile.data-application_profile.name}"
  tags = {
    "environment"             = local.environment
    "platform"                = "ubuntu"
    "application"             = "data-application"
    "name"                    = "${var.platform}-data-application"
    "office-hours-instance"   = "true"
  }
}

############################## EBS Volumes ####################################

resource "aws_ebs_volume" "data-application-first" {

  depends_on           	= [module.data-application]
  availability_zone     = "${module.data-application.availability_zone[0]}"
  size                  = 16
  type                  = "gp2"
  tags 			            = {
			                         Name	= "data-application-first-ebs-storage"
  			                  }
}

resource "aws_volume_attachment" "data-application_att" {

  device_name   = "/dev/xvdb"
  volume_id     = "${aws_ebs_volume.data-application-first.id}"
  instance_id   = "${module.data-application.id[0]}"

}

############################## IAM ####################################

resource "aws_iam_instance_profile" "data-application_profile" {
  name = "data-application_profile"
  role = "${aws_iam_role.data-application_role.name}"
}

data "template_file" "data-application_assume_role_cfg" {
  template = "${file("${path.module}/templates/assumerole_ec2.tpl")}"
}

resource "aws_iam_role" "data-application_role" {
  name = "data-application_role"
  assume_role_policy = data.template_file.data-application_assume_role_cfg.rendered
  tags = {
    "Environment" = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "data-application_attach" {
  role       = "${aws_iam_role.data-application_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

############################## Ansible ####################################

data "template_file" "data-application_ansible_role" {
  template = "${file("${path.module}/templates/data-application.yml.tpl")}"
  vars = {
    service_name : "${local.variables[terraform.workspace].ec2.data-application.service_name}"
    dns_name_of_server : "${local.variables[terraform.workspace].ec2.data-application.service_name}.${var.prod_dns}"

    }
}

resource "local_file" "data-application_roles" {
  depends_on = [ module.vpc ]
  content     = data.template_file.data-application_ansible_role.rendered
  filename = "${path.module}/../../ansible/plays/data-application.yaml"
}

data "template_file" "data-application_hosts" {
  template = "${file("${path.module}/templates/data-application_hosts.tpl")}"
  vars = {
    data-application_private_ip  =  module.data-application.private_ip[0]
    private_pem_path  =  "${var.ec2_private_pem_path}${var.prod_private_keypair}.pem"
  }
}

resource "local_file" "data-application_inventory_file" {
    depends_on  = [ module.data-application ]
    content     = data.template_file.data-application_hosts.rendered
    filename    = "${path.module}/../../ansible/hosts/data-application_hosts"
}

resource "null_resource" "data-application_ansible" {
  depends_on = [ local_file.data-application_inventory_file,module.data-application ]
  provisioner "local-exec" {
  command = "sleep 30;cd ${path.module}/../../ansible;ansible-playbook -i hosts/data-application_hosts plays/data-application.yaml"
  }
}
############################## Route 53 ####################################

resource "aws_route53_record" "data-application" {
  zone_id = "${data.aws_route53_zone.a2i-prod.zone_id}"
  name    = "${local.variables[terraform.workspace].ec2.data-application.service_name}"
  type    = "A"
  ttl     = "300"
  records = ["${module.data-application.private_ip[0]}"]
}
