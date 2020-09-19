
############################## ########### ####################################
############################# Ec2 Instances ###################################
############################## ########### ####################################

module "nifi" {

  source = "../modules/terraform-aws-ec2-instance"

  instance_count ={replace_me_node_count}

  name                        = "nifi"
  ami                         = data.aws_ami.ubuntu_bionic.id
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
                                      "Name"            = "nifi-${local.environment}"
                                      "auto-stop-start" = "false"
                                 }

}
