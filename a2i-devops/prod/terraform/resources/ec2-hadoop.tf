############################## Security Group ####################################

module "hadoop_security_group" {

  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-hadoop-${local.environment}"
  description = "Security Group for hadoop"
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
  ]
  egress_rules        = ["all-all"]
}

############################## Ec2 Instance ####################################

module "hadoop" {
  source = "../modules/terraform-aws-ec2-instance"

  instance_count = 1

  name                        = "hadoop"
  ami                         = data.aws_ami.hadoop.id
  key_name                    = var.prod_private_keypair
  instance_type               = local.variables[terraform.workspace].ec2.hadoop.type
  associate_public_ip_address = false
  cpu_credits                 = "unlimited"
  subnet_id                   = tolist(module.vpc.private_subnets)[0]
  vpc_security_group_ids      = [module.hadoop_security_group.this_security_group_id]
  iam_instance_profile        = "${aws_iam_instance_profile.hadoop_profile.name}"
  tags = {
    "environment"             = local.environment
    "platform"                = "ubuntu"
    "application"             = "hadoop"
    "name"                    = "${var.platform}-hadoop"
    "office-hours-instance"   = "True"
    "auto-stop-start"         = "True"
  }
}

############################## EBS Volumes ####################################

resource "aws_ebs_volume" "hadoop-first" {

  depends_on           	= [module.hadoop]
  availability_zone     = "${module.hadoop.availability_zone[0]}"
  size                  = 40
  type                  = "gp2"
  tags 			            = {
			                         Name	= "hadoop-first-ebs-storage"
  			                  }
}

resource "aws_volume_attachment" "hadoop_att" {

  device_name   = "/dev/xvdb"
  volume_id     = "${aws_ebs_volume.hadoop-first.id}"
  instance_id   = "${module.hadoop.id[0]}"

}

############################## IAM ####################################

resource "aws_iam_instance_profile" "hadoop_profile" {
  name = "hadoop_profile"
  role = "${aws_iam_role.hadoop_role.name}"
}

data "template_file" "hadoop_assume_role_cfg" {
  template = "${file("${path.module}/templates/assumerole_ec2.tpl")}"
}

resource "aws_iam_role" "hadoop_role" {
  name = "hadoop_role"
  assume_role_policy = data.template_file.hadoop_assume_role_cfg.rendered
  tags = {
    "Environment" = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "hadoop_attach_ec2" {
  role       = "${aws_iam_role.hadoop_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "hadoop_attach_s3" {
  role       = "${aws_iam_role.hadoop_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "hadoop_attach_ssm" {
  role       = "${aws_iam_role.hadoop_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole"
}

############################## Ansible ####################################

data "template_file" "hadoop_ansible_role" {
  template = "${file("${path.module}/templates/hadoop.yml.tpl")}"
  vars = {
    service_name : "${local.variables[terraform.workspace].ec2.hadoop.service_name}"
    dns_name_of_server : "${local.variables[terraform.workspace].ec2.hadoop.service_name}.${var.prod_dns}"

    }
}

resource "local_file" "hadoop_roles" {
  depends_on = [ module.vpc ]
  content     = data.template_file.hadoop_ansible_role.rendered
  filename = "${path.module}/../../ansible/plays/hadoop.yaml"
}

data "template_file" "hadoop_hosts" {
  template = "${file("${path.module}/templates/hadoop_hosts.tpl")}"
  vars = {
    hadoop_private_ip  =  module.hadoop.private_ip[0]
    private_pem_path  =  "${var.ec2_private_pem_path}${var.prod_private_keypair}.pem"
  }
}

resource "local_file" "hadoop_inventory_file" {
    depends_on  = [ module.hadoop ]
    content     = data.template_file.hadoop_hosts.rendered
    filename    = "${path.module}/../../ansible/hosts/hadoop_hosts"
}

resource "null_resource" "hadoop_ansible" {
  depends_on = [ local_file.hadoop_inventory_file,module.hadoop ]
  provisioner "local-exec" {
  command = "sleep 30;cd ${path.module}/../../ansible;ansible-playbook -i hosts/hadoop_hosts plays/hadoop.yaml"
  }
}
############################## Route 53 ####################################

resource "aws_route53_record" "hadoop" {
  zone_id = "${data.aws_route53_zone.a2i-prod.zone_id}"
  name    = "${local.variables[terraform.workspace].ec2.hadoop.service_name}"
  type    = "A"
  ttl     = "300"
  records = ["${module.hadoop.private_ip[0]}"]
}
