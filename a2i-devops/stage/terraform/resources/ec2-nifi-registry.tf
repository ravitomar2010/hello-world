############################## Security Group ####################################

module "nifi_registry_security_group" {
  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-nifi-registry-${local.environment}"
  description = "Security Group for nifi"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["${local.variables[terraform.workspace].vpc_cidr}"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "Ingress for SSH to nifi from within A2i"
      cidr_blocks = "${var.office_cidr},${var.prod_cidr}"
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

module "nifi-registry" {

  source = "../modules/terraform-aws-ec2-instance"

  instance_count = 1

  name                        = "nifi-registry"
  ami                         = data.aws_ami.ubuntu_xenial.id
  key_name                    = var.stage_private_keypair
  instance_type               = local.variables[terraform.workspace].ec2.nifi-registry.type
  associate_public_ip_address = false
  cpu_credits                 = "unlimited"
  subnet_id                   = tolist(module.vpc.private_subnets)[0]
  vpc_security_group_ids      = [module.nifi_registry_security_group.this_security_group_id]
  iam_instance_profile        = "${aws_iam_instance_profile.nifi_registry_profile.name}"

  tags                        =  {
                                      "Environment"     = local.environment
                                      "Application"     = "nifi-registry"
                                      "Name"            = "${var.platform}-nifi-registry"
                                      "auto-stop-start" = "false"
                                 }

}

############################## EBS Volumes ####################################

resource "aws_ebs_volume" "nifi-registry-first" {

  depends_on           	= [module.nifi-registry]
  availability_zone     = "${module.nifi-registry.availability_zone[0]}"
  size                  = 1
  type                  = "gp2"
  tags 			            = {
			                         Name	= "nifi-registry-first-ebs-storage"
  			                  }
}

resource "aws_volume_attachment" "nifi_registry_att" {

  device_name   = "/dev/xvdb"
  volume_id     = "${aws_ebs_volume.nifi-registry-first.id}"
  instance_id   = "${module.nifi-registry.id[0]}"

}

##############################      IAM     ####################################

data "template_file" "nifi_registry_assume_role_cfg" {
  template = "${file("${path.module}/templates/assumerole_ec2.tpl")}"
}

resource "aws_iam_instance_profile" "nifi_registry_profile" {
  name = "nifi_registry_profile"
  role = "${aws_iam_role.nifi_registry_role.name}"
}

resource "aws_iam_role" "nifi_registry_role" {
  name = "nifi_registry_role"
  assume_role_policy = data.template_file.nifi_registry_assume_role_cfg.rendered
  tags = {
    "Environment" = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "nifi_registry_attach" {
  role       = "${aws_iam_role.nifi_registry_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

############################## Ansible ####################################

data "template_file" "nifi_registry_ansible_role" {
  template = "${file("${path.module}/templates/nifi_registry.yml.tpl")}"
  vars = {
    service_name                : "${local.variables[terraform.workspace].ec2.nifi-registry.service_name}"
    dns_name_of_server          : "${local.variables[terraform.workspace].ec2.nifi-registry.service_name}.${var.infra_dns}"
    nifi_registry_git_user_ssm  : "${local.variables[terraform.workspace].ec2.nifi-registry.nifi_registry_git_user_ssm_path}"
  }
}

resource "local_file" "nifi_registry_roles" {
  depends_on = [ aws_eip.pritunl, module.pritunl, local_file.ssh_cfg ]
  content     = data.template_file.nifi_registry_ansible_role.rendered
  filename = "${path.module}/../../ansible/plays/nifi_registry.yaml"
}

data "template_file" "nifi_registry_hosts" {
  template = "${file("${path.module}/templates/nifi_resgistry_hosts.tpl")}"
  vars = {
    nifi_registry_private_ip      =  module.nifi-registry.private_ip[0]
    private_pem_path     =  "${var.ec2_private_pem_path}${var.stage_private_keypair}.pem"
  }
}

resource "local_file" "nifi_registry_inventory_file" {
  depends_on = [ aws_eip.pritunl, module.nifi-registry ]
  content     = data.template_file.nifi_registry_hosts.rendered
  filename = "${path.module}/../../ansible/hosts/nifi_registry_hosts"
}

resource "null_resource" "nifi_registry_ansible" {
  depends_on = [ local_file.nifi_registry_inventory_file, aws_eip.pritunl, module.nifi-registry ]
  provisioner "local-exec" {
    command = "sleep 30;cd ${path.module}/../../ansible;ansible-playbook -i hosts/nifi_registry_hosts plays/nifi_registry.yaml"
  }
}

############################## Route 53 ####################################

resource "aws_route53_record" "nifi-registry" {
  zone_id = "${data.aws_route53_zone.a2i-infra.zone_id}"
  name    = "${local.variables[terraform.workspace].ec2.nifi-registry.service_name}"
  type    = "A"
  ttl     = "300"
  records = ["${module.nifi-registry.private_ip[0]}"]
}
