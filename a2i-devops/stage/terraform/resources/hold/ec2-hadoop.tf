############################## Security Group ####################################

module "hadoop_security_group" {
  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-hadoop-${local.environment}"
  description = "Security Group for hadoop"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["${local.variables[terraform.workspace].vpc_cidr}"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "Ingress for hadoop SSH from within VPC"
      cidr_blocks = "${var.office_cidr},${var.prod_cidr}"
    },
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "Ingress for all traffic within VPC"
      cidr_blocks = "${var.stage_cidr},${chomp(data.http.myip.body)}/32"
    },
  ]
  egress_rules        = ["all-all"]
}


############################## EC2 Instance ####################################

module "hadoop" {
  source = "../modules/terraform-aws-ec2-instance"

  instance_count = 1

  name                        = "${var.platform}-hadoop-${local.environment}"
  ami                         = data.aws_ami.hadoop.id
  key_name                    = var.platform_private_keypair
  instance_type               = local.variables[terraform.workspace].ec2.hadoop.type
  associate_public_ip_address = true
  cpu_credits                 = "unlimited"
  subnet_id                   = tolist(module.vpc.private_subnets)[0]
  vpc_security_group_ids      = [module.hadoop_security_group.this_security_group_id]
  iam_instance_profile        = "${aws_iam_instance_profile.hadoop_profile.name}"

  tags = {
    "Environment"     = local.environment
    "Application"     = "hadoop"
    "Name"            = "${var.platform}-hadoop-${local.environment}"
    "auto-stop-start" = "true"
  }
}

############################## IAM ####################################

data "template_file" "hadoop_assume_role_cfg" {
  template = "${file("${path.module}/templates/assumerole_ec2.tpl")}"
}

resource "aws_iam_instance_profile" "hadoop_profile" {
  name = "hadoop_profile"
  role = "${aws_iam_role.hadoop_role.name}"
}

resource "aws_iam_role" "hadoop_role" {
  name = "hadoop_role"
  assume_role_policy = data.template_file.hadoop_assume_role_cfg.rendered
  tags = {
    "Environment" = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "hadoop_attach" {
  role       = "${aws_iam_role.hadoop_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}


############################## Ansible ####################################

data "template_file" "hadoop_server_hosts" {
  template = "${file("${path.module}/templates/hadoop_server_hosts.tpl")}"
  vars = {
    hadoop_private_ip  =  module.hadoop.private_ip[0]
    private_pem_path  =  var.ec2_private_pem_path
  }
}

resource "local_file" "hadoop_server_inventory_file" {
  depends_on = [ aws_eip.pritunl, module.hadoop ]
  content     = data.template_file.hadoop_server_hosts.rendered
  filename = "${path.module}/../../ansible/hosts/hadoop_server_hosts"
}

data "template_file" "hadoop_server_ansible_role" {
  template = "${file("${path.module}/templates/hadoop_server.yml.tpl")}"
}

resource "local_file" "hadoop_server_roles" {
  depends_on = [ aws_eip.pritunl, module.pritunl, local_file.ssh_cfg ]
  content     = data.template_file.hadoop_server_ansible_role.rendered
  filename = "${path.module}/../../ansible/plays/hadoop_server.yaml"
}

resource "null_resource" "hadoop_server_ansible" {
  depends_on = [ local_file.ldap_server_inventory_file, aws_eip.pritunl, module.ldap_server ]
  provisioner "local-exec" {
    command = "sleep 30; cd ${path.module}/../../ansible;ansible-playbook -i hosts/hadoop_server_hosts plays/hadoop_server.yaml"
  }
}

############################## Route53 ####################################

resource "aws_route53_record" "hadoop" {
  zone_id = "${aws_route53_zone.a2i-stage.zone_id}"
  name    = "hadoop"
  type    = "A"
  ttl     = "300"
  records = ["${module.hadoop.private_ip[0]}"]
}
