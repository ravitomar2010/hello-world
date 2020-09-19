############################## Security Group ####################################

module "pritunl_security_group" {
  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-pritunl-${local.environment}"
  description = "Security Group for Pritunl"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["${local.variables[terraform.workspace].vpc_cidr}"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 11000
      to_port     = 11000
      protocol    = "tcp"
      description = "Ingress for VPN client connections for prod"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 12000
      to_port     = 12000
      protocol    = "tcp"
      description = "Ingress for VPN client connections for stage"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "Ingress for SSH only from the terraform workstation"
      cidr_blocks = "${var.office_cidr},${var.prod_cidr}"
    },
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "Allowed all traffic from workstation"
      cidr_blocks = "${chomp(data.http.myip.body)}/32,${var.stage_cidr}"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Ingress for HTTPS from anywhere"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "Ingress for HTTP from anywhere"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
 # ingress_rules       = ["https-443-tcp"]
  egress_rules        = ["all-all"]
}


############################## Elastic IP ####################################

resource "aws_eip" "pritunl" {
  vpc      = true
  instance = module.pritunl.id[0]
  tags = {
    Name = "${var.platform}-pritunl-eip-${local.environment}"
  }
}

############################## EC2 instance ####################################

module "pritunl" {
  source = "../modules/terraform-aws-ec2-instance"

  instance_count = 1

  name                        = "${var.platform}-pritunl-${local.environment}"
  ami                         = data.aws_ami.ubuntu_bionic.id
  key_name                    = var.jump_private_keypair
  instance_type               = local.variables[terraform.workspace].ec2.pritunl.type
  associate_public_ip_address = true
  cpu_credits                 = "unlimited"
  subnet_id                   = tolist(module.vpc.public_subnets)[0]
  vpc_security_group_ids      = [module.pritunl_security_group.this_security_group_id]
  iam_instance_profile        = "${aws_iam_instance_profile.pritunl_profile.name}"
  tags = {
    "Environment"     = "infra"
    "Application"     = "pritunl"
    "Name"            = "${var.platform}-pritunl-server-${local.environment}"
    "auto-stop-start" = "false"
  }
}

############################## EBS Volumes ####################################

resource "aws_ebs_volume" "pritunl-first" {
  depends_on           	= [module.pritunl]
  availability_zone     = "${module.pritunl.availability_zone[0]}"
  size                  = 5
  type                  = "gp2"
  tags 			= {
			    Name	= "pritunl-first-ebs-storage"
  			  }
}

resource "aws_volume_attachment" "pritunl_att" {
  device_name   = "/dev/xvdb"
  volume_id     = "${aws_ebs_volume.pritunl-first.id}"
  instance_id   = "${module.pritunl.id[0]}"
}

############################## IAM ####################################

data "template_file" "assume_role_cfg" {
  template = "${file("${path.module}/templates/assumerole_ec2.tpl")}"
}

resource "aws_iam_instance_profile" "pritunl_profile" {
  name = "pritunl_profile"
  role = "${aws_iam_role.pritunl_role.name}"
}

resource "aws_iam_role" "pritunl_role" {
  name = "pritunl_role"
  assume_role_policy = data.template_file.assume_role_cfg.rendered
  tags = {
    "Environment" = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "pritunl_attach" {
  role       = "${aws_iam_role.pritunl_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}


############################## Ansible ####################################

data "template_file" "pritunl_ansible_role" {
  template = "${file("${path.module}/templates/pritunl.yml.tpl")}"
  vars = {
    vault_password = "${var.vault_password_pritunl}"
    service_name = "${local.variables[terraform.workspace].ec2.pritunl.service_name}"
    dns_name_of_server = "${local.variables[terraform.workspace].ec2.pritunl.service_name}.${var.infra_dns}"
  }
}

data "template_file" "pritunl_ansible_hosts" {
  template = "${file("${path.module}/templates/pritunl_hosts.tpl")}"
  vars = {
    pritunl_public_ip  =  aws_eip.pritunl.public_ip
    pem_path           =  "${var.ec2_jump_pem_path}${var.jump_private_keypair}.pem"
  }
}

data "template_file" "ssh_cfg" {
  template = "${file("${path.module}/templates/ssh.cfg.tpl")}"
  vars = {
    pritunl_public_ip        =  aws_eip.pritunl.public_ip
    infra_hosts              =  var.ssh_jump_target_infra
    stage_hosts              =  var.ssh_jump_target
    jump_pem_path            =  "${var.ec2_jump_pem_path}${var.jump_private_keypair}.pem"
    infra_private_pem_path   =  "${var.ec2_jump_pem_path}${var.infra_private_keypair}.pem"
    stage_private_pem_path   =  "${var.ec2_jump_pem_path}${var.stage_private_keypair}.pem"
  }
}

resource "local_file" "ssh_cfg" {
  depends_on = [ aws_eip.pritunl, module.pritunl ]
  content     =  data.template_file.ssh_cfg.rendered
  filename = "${path.module}/../../ansible/ssh.cfg"
}

resource "local_file" "pritunl_hosts" {
  depends_on = [ aws_eip.pritunl, module.pritunl, local_file.ssh_cfg ]
  content     = data.template_file.pritunl_ansible_hosts.rendered
  filename = "${path.module}/../../ansible/hosts/pritunl"
}

resource "local_file" "pritunl_roles" {
  depends_on = [ aws_eip.pritunl, module.pritunl, local_file.ssh_cfg ]
  content     = data.template_file.pritunl_ansible_role.rendered
  filename = "${path.module}/../../ansible/plays/pritunl.yaml"
}

resource "null_resource" "pritunl_ansible" {
  depends_on = [ local_file.pritunl_roles, aws_eip.pritunl, module.pritunl, local_file.ssh_cfg ]
  provisioner "local-exec" {
    command = "sleep 10;cd ${path.module}/../../ansible;ansible-playbook -i hosts/pritunl plays/pritunl.yaml"
  }
}

############################## Route 53 ####################################


resource "aws_route53_record" "pritunl" {
  zone_id = "${data.aws_route53_zone.a2i-infra.zone_id}"
  name    = "${local.variables[terraform.workspace].ec2.pritunl.service_name}"
  type    = "A"
  ttl     = "300"
  records = ["${module.pritunl.private_ip[0]}"]
}
