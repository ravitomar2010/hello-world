############################## Security Group ####################################

module "zk-server_security_group" {
  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-zk-server-${local.environment}"
  description = "Security Group for zk-server"
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


############################## Ec2 Instance ####################################

module "zk-server" {

  source = "../modules/terraform-aws-ec2-instance"

  instance_count = 2

  name                        = "zk-server"
  ami                         = data.aws_ami.ubuntu_xenial.id
  key_name                    = var.stage_private_keypair
  instance_type               = local.variables[terraform.workspace].ec2.zk-server.type
  associate_public_ip_address = true
  cpu_credits                 = "unlimited"
  subnet_id                   = tolist(module.vpc.public_subnets)[0]
  vpc_security_group_ids      = [module.zk-server_security_group.this_security_group_id]
  iam_instance_profile        = "${aws_iam_instance_profile.zk-server_profile.name}"

  tags                        =  {
                                      "Environment"     = local.environment
                                      "Application"     = "zk-server"
                                      "Name"            = "${var.platform}-zk-server-${local.environment}"
                                      "auto-stop-start" = "false"
                                 }

}

############################## EBS Volumes ####################################

#resource "aws_ebs_volume" "zk-server-first" {
#  depends_on           	= [module.zk-server]
#  availability_zone     = "${module.zk-server.availability_zone[0]}"
#  size                  = 3
#  type                  = "gp2"
#  tags 			            = {
#			                         Name	= "zk-server-first-ebs-storage"
#  			                  }
#}
#resource "aws_volume_attachment" "zk-server_att" {
#  device_name   = "/dev/xvdb"
#  volume_id     = "${aws_ebs_volume.zk-server-first.id}"
#  instance_id   = "${module.zk-server.id[0]}"
#}

##############################      IAM     ####################################

data "template_file" "zk-server_assume_role_cfg" {
  template = "${file("${path.module}/templates/assumerole_ec2.tpl")}"
}

resource "aws_iam_instance_profile" "zk-server_profile" {
  name = "zk-server_profile"
  role = "${aws_iam_role.zk-server_role.name}"
}

resource "aws_iam_role" "zk-server_role" {
  name = "zk-server_role"
  assume_role_policy = data.template_file.zk-server_assume_role_cfg.rendered
  tags = {
    "Environment" = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "zk-server_attach" {
  role       = "${aws_iam_role.zk-server_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

############################## Ansible ####################################

data "template_file" "zk-server_ansible_role" {
  template = "${file("${path.module}/templates/zk-server.yml.tpl")}"
  vars = {
      zk_version              : "${local.variables[terraform.workspace].ec2.zk-server.zk_version}"
      zk_server_id            : "${local.variables[terraform.workspace].ec2.zk-server.zk_server_id}"
      env_dns                 : "${local.variables[terraform.workspace].ec2.zk-server.env_dns}"
      service_name            : "${local.variables[terraform.workspace].ec2.zk-server.service_name}"
      dns_name_of_server      : "${local.variables[terraform.workspace].ec2.zk-server.service_name}.${var.stage_dns}"
  }
}
resource "local_file" "zk-server_roles" {
  depends_on = [ aws_eip.pritunl, module.pritunl, local_file.ssh_cfg ]
  content     = data.template_file.zk-server_ansible_role.rendered
  filename = "${path.module}/../../ansible/plays/zk-server.yaml"
}
data "template_file" "zk-server_hosts" {
  template = "${file("${path.module}/templates/zk-server_hosts.tpl")}"
  vars = {
    zk-server_private_ip  =  module.zk-server.private_ip[0]
    private_pem_path =  "${var.ec2_private_pem_path}${var.stage_private_keypair}.pem"
  }
}
resource "local_file" "zk-server_inventory_file" {
  depends_on = [ aws_eip.pritunl, module.zk-server ]
  content     = data.template_file.zk-server_hosts.rendered
  filename = "${path.module}/../../ansible/hosts/zk-server_hosts"
}
#resource "null_resource" "zk-server_ansible" {
#  depends_on = [ local_file.zk-server_inventory_file, aws_eip.pritunl, module.zk-server ]
#  provisioner "local-exec" {
#    command = "sleep 30;cd ${path.module}/../../ansible;ansible-playbook -i hosts/zk-server_hosts plays/zk-server.yaml"
#  }
#}


############################## Route 53 ####################################

resource "aws_route53_record" "zk-server" {
  zone_id = "${aws_route53_zone.a2i-stage.zone_id}"
  name    = "${local.variables[terraform.workspace].ec2.zk-server.service_name}"
  type    = "A"
  ttl     = "300"
  records = ["${module.zk-server.private_ip[0]}"]
}
resource "aws_route53_record" "zk-server-2" {
  zone_id = "${aws_route53_zone.a2i-stage.zone_id}"
  name    = "zk-2"
  type    = "A"
  ttl     = "300"
  records = ["${module.zk-server.private_ip[0]}"]
}
resource "aws_route53_record" "zk-server-3" {
  zone_id = "${aws_route53_zone.a2i-stage.zone_id}"
  name    = "zk-3"
  type    = "A"
  ttl     = "300"
  records = ["${module.zk-server.private_ip[1]}"]
}
