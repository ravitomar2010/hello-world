############################## Security Group ####################################

module "nifi_security_group" {
  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-nifi-${local.environment}"
  description = "Security Group for nifi"
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

module "nifi" {

  source = "../modules/terraform-aws-ec2-instance"

  instance_count = replace_me_node_count

  name                        = "nifi"
  ami                         = data.aws_ami.ubuntu_xenial.id
  key_name                    = var.stage_private_keypair
  instance_type               = local.variables[terraform.workspace].ec2.nifi.type
  associate_public_ip_address = false
  cpu_credits                 = "unlimited"
  subnet_id                   = tolist(module.vpc.private_subnets)[0]
  vpc_security_group_ids      = [module.nifi_security_group.this_security_group_id]
  iam_instance_profile        = "${aws_iam_instance_profile.nifi_profile.name}"

  tags                        =  {
                                      "Environment"     = local.environment
                                      "Application"     = "nifi"
                                      "Name"            = "${var.platform}-nifi-${local.environment}"
                                      "auto-stop-start" = "false"
                                 }

}

############################## EBS Volumes ####################################

resource "aws_ebs_volume" "replace_me_node-first" {

  depends_on           	= [module.nifi]
  availability_zone     = "${module.nifi.availability_zone[0]}"
  size                  = 1
  type                  = "gp2"
  tags 			            = {
			                         Name	= "nifi-first-ebs-storage"
  			                  }
}

resource "aws_volume_attachment" "nifi_att" {

  device_name   = "/dev/xvdb"
  volume_id     = "${aws_ebs_volume.nifi-first.id}"
  instance_id   = "${module.nifi.id[0]}"

}

##############################      IAM     ####################################

data "template_file" "nifi_assume_role_cfg" {
  template = "${file("${path.module}/templates/assumerole_ec2.tpl")}"
}

resource "aws_iam_instance_profile" "nifi_profile" {
  name = "nifi_profile"
  role = "${aws_iam_role.nifi_role.name}"
}

resource "aws_iam_role" "nifi_role" {
  name = "nifi_role"
  assume_role_policy = data.template_file.nifi_assume_role_cfg.rendered
  tags = {
    "Environment" = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "nifi_attach" {
  role       = "${aws_iam_role.nifi_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

############################## Ansible ####################################

data "template_file" "nifi_hosts" {
  template = "${file("${path.module}/templates/nifi_hosts.tpl")}"
  vars = {
    nifi_private_ip  =  module.nifi.private_ip[0]
    private_pem_path =  "${var.ec2_private_pem_path}${var.stage_private_keypair}.pem"
  }
}

data "template_file" "nifi_ansible_role" {
  template = "${file("${path.module}/templates/nifi.yml.tpl")}"
  vars = {
    manager_dn              : "${local.variables[terraform.workspace].ec2.nifi.manager_dn}"
    url                     : "${local.variables[terraform.workspace].ec2.nifi.ldap_url}"
    user_search_base        : "${local.variables[terraform.workspace].ec2.nifi.user_search_base}"
    user_filter             : "${local.variables[terraform.workspace].ec2.nifi.user_filter}"
    group_search_base       : "${local.variables[terraform.workspace].ec2.nifi.group_search_base}"
    node_identity_cn        : "${local.variables[terraform.workspace].ec2.nifi.node_identity_cn}"
    initial_admin_id        : "${local.variables[terraform.workspace].ec2.nifi.initial_admin_id}"
    nifi_binduserpath_ssm   : "${local.variables[terraform.workspace].ec2.nifi.binduserpath_ssm}"
  }
}
resource "local_file" "nifi_roles" {
  depends_on = [ aws_eip.pritunl, module.pritunl, local_file.ssh_cfg ]
  content     = data.template_file.nifi_ansible_role.rendered
  filename = "${path.module}/../../ansible/plays/nifi.yaml"
}
resource "null_resource" "nifi_ansible" {
  depends_on = [ local_file.nifi_inventory_file, aws_eip.pritunl, module.nifi ]
  provisioner "local-exec" {
    command = "sleep 30;cd ${path.module}/../../ansible;ansible-playbook -i hosts/nifi_hosts plays/nifi.yaml"
  }
}

############################## Route 53 ####################################

resource "aws_route53_record" "nifi" {
  zone_id = "${aws_route53_zone.a2i-stage.zone_id}"
  name    = "${local.variables[terraform.workspace].ec2.nifi.service_name}"
  type    = "A"
  ttl     = "300"
  records = ["${module.nifi.private_ip[0]}"]
}
