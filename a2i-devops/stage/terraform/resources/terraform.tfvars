platform                  = "a2i"
aws_region                = "eu-west-1"
ssh_jump_target           = "10.*"
ssh_jump_target_infra     = "10.12.12.*, 10.12.10.*"
jump_ingress_public_ip    = "61.12.91.218/32,182.71.160.186/32"
ec2_private_pem_path      = "~/"
ec2_jump_pem_path         = "~/"
vault_password_pritunl    = "PrItUnL@007"
jump_private_keypair      = "a2i-jump"
infra_private_keypair     = "a2i-infra"
prod_private_keypair      = "a2i-prod"
stage_private_keypair     = "a2i-stage"