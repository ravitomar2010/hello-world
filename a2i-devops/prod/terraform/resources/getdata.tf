############################## Take my IP ####################################

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}


############################## Fetch route53 zone info ####################################

data "aws_route53_zone" "a2i-prod" {
    name         = "a2i.prod"
    private_zone = true
}
