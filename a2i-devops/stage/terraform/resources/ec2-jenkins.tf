############################## Security Group ####################################

module "jenkins_security_group" {
  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-jenkins-${local.environment}-"
  description = "Security Group for jenkins"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["${local.variables[terraform.workspace].vpc_cidr}"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      description = "Ingress for Elastic API port from withing VPC"
      cidr_blocks =  "${var.office_cidr}"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "Ingress for SSH only from the terraform workstation"
      cidr_blocks = "${var.office_cidr}"
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


module "jenkins" {
  source = "../modules/terraform-aws-ec2-instance"

  instance_count = 1

  name                        = "jenkins"
  ami                         = data.aws_ami.ubuntu_bionic.id
  key_name                    = var.infra_private_keypair
  instance_type               = local.variables[terraform.workspace].ec2.jenkins.type
  associate_public_ip_address = false
  cpu_credits                 = "unlimited"
  subnet_id                   = tolist(module.vpc.infra_subnets)[0]
  vpc_security_group_ids      = [module.jenkins_security_group.this_security_group_id]
  iam_instance_profile        = "${aws_iam_instance_profile.jenkins_profile.name}"
  tags = {
    "Environment"     = "infra"
    "Application"     = "jenkins"
    "Name"            = "${var.platform}-jenkins"
    "auto-stop-start" = "false"
  }
}

############################## EBS Volumes ####################################

resource "aws_ebs_volume" "jenkins-first" {
  depends_on           	= [module.jenkins]
  availability_zone     = "${module.jenkins.availability_zone[0]}"
  size                  = 25
  type                  = "gp2"
  tags 			= {
			    Name	= "jenkins-first-ebs-storage"
  			  }
}

resource "aws_volume_attachment" "jenkins_att" {
  device_name   = "/dev/xvdb"
  volume_id     = "${aws_ebs_volume.jenkins-first.id}"
  instance_id   = "${module.jenkins.id[0]}"
}

############################## IAM ####################################

resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "jenkins_profile"
  role = "${aws_iam_role.jenkins_role.name}"
}

data "template_file" "jenkins_assume_role_cfg" {
  template = "${file("${path.module}/templates/assumerole_ec2.tpl")}"
}

resource "aws_iam_role" "jenkins_role" {
  name = "jenkins_role"
  assume_role_policy = data.template_file.jenkins_assume_role_cfg.rendered
  tags = {
    "Environment" = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "jenkins_attach" {
  role       = "${aws_iam_role.jenkins_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}


############################## Ansible ####################################


data "template_file" "jenkins_hosts" {
  template = "${file("${path.module}/templates/jenkins_hosts.tpl")}"
  vars = {
    jenkins_private_ip  =  module.jenkins.private_ip[0]
    private_pem_path    =  "${var.ec2_private_pem_path}${var.infra_private_keypair}.pem"
  }
}

resource "local_file" "jenkins_inventory_file" {
  depends_on = [ aws_eip.pritunl, module.jenkins ]
  content     = data.template_file.jenkins_hosts.rendered
  filename = "${path.module}/../../ansible/hosts/jenkins_hosts"
}

data "template_file" "jenkins_ansible_role" {
  template = "${file("${path.module}/templates/jenkins.yml.tpl")}"
  vars = {
    shared_library_repo = "${local.variables[terraform.workspace].ec2.jenkins.shared_library_repo}"
    shared_library_name = "${local.variables[terraform.workspace].ec2.jenkins.shared_library_name}"
    shared_library_default_version = "${local.variables[terraform.workspace].ec2.jenkins.shared_library_default_version}"
    onboard_job_repo = "${local.variables[terraform.workspace].ec2.jenkins.onboard_job_repo}"
    onboard_job_configure_branch = "${local.variables[terraform.workspace].ec2.jenkins.onboard_job_configure_branch}"
    service_name : "${local.variables[terraform.workspace].ec2.jenkins.service_name}"
    dns_name_of_server : "${local.variables[terraform.workspace].ec2.jenkins.service_name}.${var.infra_dns}"
  }
}

resource "local_file" "jenkins_roles" {
  depends_on = [ aws_eip.pritunl, module.pritunl, local_file.ssh_cfg ]
  content     = data.template_file.jenkins_ansible_role.rendered
  filename = "${path.module}/../../ansible/plays/jenkins.yaml"
}

resource "null_resource" "jenkins_ansible" {
  depends_on = [ local_file.jenkins_roles, local_file.jenkins_inventory_file, aws_eip.pritunl, module.jenkins ]
  provisioner "local-exec" {
    command = "sleep 30;cd ${path.module}/../../ansible;ansible-playbook -i hosts/jenkins_hosts plays/jenkins.yaml"
  }
}

############################## Route53 ####################################


resource "aws_route53_record" "jenkins" {
  zone_id = "${data.aws_route53_zone.a2i-infra.zone_id}"
  name    = "${local.variables[terraform.workspace].ec2.jenkins.service_name}"
  type    = "A"
  ttl     = "300"
  records = ["${module.jenkins.private_ip[0]}"]
}

resource "aws_route53_record" "sonarqube" {
  zone_id = "${data.aws_route53_zone.a2i-infra.zone_id}"
  name    = "sonarqube"
  type    = "A"
  ttl     = "300"
  records = ["${module.jenkins.private_ip[0]}"]
}
