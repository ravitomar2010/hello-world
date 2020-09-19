############################## Take my IP ####################################

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

#################### Fetch parameters from parameter store ##################

data "aws_ssm_parameter" "openldap_server_rootpw" {
  name = "/a2i/infra/ldap/rootpwd"
  with_decryption = "true"
}


data "aws_ssm_parameter" "openldap_server_bindpw" {
  name = "/a2i/infra/ldap/bindpwd"
  with_decryption = "true"
}


data "aws_ssm_parameter" "redshift_rootpw" {
  name = "/a2i/infra/redshift_stage/rootpassword"
  with_decryption = "true"
}

############################## Fetch route53 zone info ####################################

data "aws_route53_zone" "a2i-infra" {
    name         = "a2i.infra"
    private_zone = true
}

data "aws_route53_zone" "a2i-stage" {
    name         = "a2i.stage"
    private_zone = true
}
