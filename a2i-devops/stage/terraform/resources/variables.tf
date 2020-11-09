## Environment and Provider Inputs
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

variable "platform" {
  description = "Platform for which infrastructure is being developed"
}

variable "aws_region" {
  description = "Region where resources would be created"
}

variable "ssh_jump_target" {
  description = "Define the enviroment such as production/development/qa"
}

variable "ssh_jump_target_infra" {
  description = "Define the enviroment such as production/development/qa/ infra"
}

variable "jump_ingress_public_ip" {
  description = "Public IP of the network from where ssh to the pritunl instance would be done"
}

variable "jump_private_keypair" {
  description = "Name of the keypair for platform instances"
}

variable "infra_private_keypair" {
  description = "Name of the keypair for platform instances"
}

variable "prod_private_keypair" {
  description = "Name of the keypair for platform instances"
}

variable "stage_private_keypair" {
  description = "Name of the keypair for platform instances"
}


variable "ec2_jump_pem_path" {

}

variable "ec2_private_pem_path" {

}
variable "vault_password_pritunl" {
  description = "Vault pritunl password"
}
variable "domain_name" {
  description = "Domain name to use as Route53 zone and ACM certificate"
  default     = "hyke.ai"
}

variable "office_cidr" {
  description = "CIDR used by office local network to allow traffic without VPN"
  default     = "172.27.0.0/16"
}
variable "prod_cidr" {
  description = "CIDR used by office local network to allow traffic without VPN"
  default     = "10.11.0.0/16"
}
variable "old_prod_cidr" {
  description = "CIDR used by office local network to allow traffic without VPN"
  default     = "10.10.0.0/16"
}
variable "stage_cidr" {
  description = "CIDR used by office local network to allow traffic without VPN"
  default     = "10.12.0.0/16"
}

variable "dot" {
  description = "DNS name used for infra networks"
  default = "."
}
variable "infra_dns" {
  description = "DNS name used for infra networks"
  default     = "a2i.infra"
}
variable "stage_dns" {
  description = "DNS name used for infra networks"
  default     = "a2i.stage"
}
