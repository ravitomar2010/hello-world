############################## ########### ####################################
############################ Security Groups ##################################
############################## ########### ####################################

module "ml_security_group" {
  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-ml-${local.environment}"
  description = "Security Group for ml"
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

############################## ########### ####################################
############################# Ec2 Instances ###################################
############################## ########### ####################################

module "ml" {

  source = "../modules/terraform-aws-ec2-instance"

  instance_count =       1

  name                        = "ml-stage"
  ami                         = data.aws_ami.ubuntu_bionic.id
  key_name                    = var.stage_private_keypair
  instance_type               = local.variables[terraform.workspace].ec2.ml.type
  associate_public_ip_address = false
  cpu_credits                 = "unlimited"
  subnet_id                   = tolist(module.vpc.private_subnets)[0]
  vpc_security_group_ids      = [module.ml_security_group.this_security_group_id]
  iam_instance_profile        = "${aws_iam_instance_profile.ml_profile.name}"

  tags                        =  {
                                      "Environment"           = local.environment
                                      "Application"           = "ml"
                                      "Name"                  = "${var.platform}-ml-${local.environment}"
                                      "auto-stop-start"       = "false"
                                      "office-hours-instance" = "true"
                                 }
}
############################## ########### ####################################
############################## EBS Volumes ####################################
############################## ########### ####################################

###### EBS resource for ml-1

resource "aws_ebs_volume" "ml-1-first" {

  depends_on           	= [module.ml]
  availability_zone     = "${module.ml.availability_zone[0]}"
  size                  = 1
  type                  = "gp2"
  tags 			            = {
			                         Name	= "ml-1-first-ebs-storage"
  			                  }
}

resource "aws_volume_attachment" "ml-1_att" {

  device_name   = "/dev/xvdb"
  volume_id     = "${aws_ebs_volume.ml-1-first.id}"
  instance_id   = "${module.ml.id[0]}"

}

############################## ########### ####################################
##############################     IAM     ####################################
############################## ########### ####################################

data "template_file" "ml_assume_role_cfg" {
  template = "${file("${path.module}/templates/assumerole_ec2.tpl")}"
}

resource "aws_iam_instance_profile" "ml_profile" {
  name = "ml_profile"
  role = "${aws_iam_role.ml_role.name}"
}

resource "aws_iam_role" "ml_role" {
  name = "ml_role"
  assume_role_policy = data.template_file.ml_assume_role_cfg.rendered
  tags = {
    "Environment" = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "ml_attach" {
  role       = "${aws_iam_role.ml_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

############################## ########### ####################################
##############################   Ansible   ####################################
############################## ########### ####################################

data "template_file" "ml_hosts" {
  template = "${file("${path.module}/templates/ml_hosts.tpl")}"
  vars = {
            ml_private_ip =  module.ml.private_ip[0]
            private_pem_path       =  "${var.ec2_private_pem_path}${var.stage_private_keypair}.pem"
            }
}

resource "local_file" "ml_inventory_file" {
  depends_on = [ aws_eip.pritunl, module.ml ]
  content     = data.template_file.ml_hosts.rendered
  filename = "${path.module}/../../ansible/hosts/ml_hosts"
}

data "template_file" "ml_ansible_role" {
  template = "${file("${path.module}/templates/ml.yml.tpl")}"
  vars = {
        service_name            : "${local.variables[terraform.workspace].ec2.ml.service_name}"
        dns_name_of_server      : "${local.variables[terraform.workspace].ec2.ml.service_name}.${var.stage_dns}"
         }
}

resource "local_file" "ml_roles" {
  depends_on = [ aws_eip.pritunl, module.pritunl, local_file.ssh_cfg ]
  content     = data.template_file.ml_ansible_role.rendered
  filename = "${path.module}/../../ansible/plays/ml.yaml"
}

resource "null_resource" "ml_ansible" {
  depends_on = [ local_file.ml_roles, local_file.ml_inventory_file, aws_eip.pritunl, module.ml ]
  provisioner "local-exec" {
    command = "sleep 30;cd ${path.module}/../../ansible;ansible-playbook -i hosts/ml_hosts plays/ml.yaml"
  }
}

############################## ########### ####################################
##############################   Route 53  ####################################
############################## ########### ####################################

######################### Route 53 for node ml-1 #################################

resource "aws_route53_record" "r53ml" {
  zone_id = "${data.aws_route53_zone.a2i-stage.zone_id}"
  name    = "ml"
  type    = "A"
  ttl     = "300"
  records = ["${module.ml.private_ip[0]}"]
}
