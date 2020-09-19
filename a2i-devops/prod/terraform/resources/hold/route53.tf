
####Everything is commented and will be created manually

/*
resource "aws_route53_zone" "a2i-stage" {
  name    = "a2i.stage"

  vpc {
    vpc_id = module.vpc.vpc_id
  }
}


resource "aws_route53_zone" "a2i-infra" {
  name    = "a2i.infra"
  vpc {
    vpc_id = module.vpc.vpc_id
  }
}

resource "null_resource" "stagetoprod_association" {

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "aws route53 associate-vpc-with-hosted-zone --hosted-zone-id \"Z02262471JWHMXFG9ICGM\" --vpc \"VPCRegion=eu-west-1,VPCId=vpc-08556c49da6c6f3c1\" --profile prod"
    }
}

resource "null_resource" "stagetoprod_authorization" {

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "aws route53 create-vpc-association-authorization --hosted-zone-id \"Z02262471JWHMXFG9ICGM\" --vpc \"VPCRegion=eu-west-1,VPCId=vpc-08556c49da6c6f3c1\" --profile stage"
    }
}


resource "null_resource" "infratoprod_association" {

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "aws route53 associate-vpc-with-hosted-zone --hosted-zone-id \"Z022622321HG7G07ECKFC\" --vpc \"VPCRegion=eu-west-1,VPCId=vpc-08556c49da6c6f3c1\" --profile prod"
    }
}

resource "null_resource" "infratoprod_authorization" {

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "aws route53 create-vpc-association-authorization --hosted-zone-id \"Z022622321HG7G07ECKFC\" --vpc \"VPCRegion=eu-west-1,VPCId=vpc-08556c49da6c6f3c1\" --profile stage"
    }
}

resource "null_resource" "infratoprod" {

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = 'aws route53 associate-vpc-with-hosted-zone --hosted-zone-id "Z022622321HG7G07ECKFC" --vpc "VPCRegion=eu-west-1,VPCId=vpc-08556c49da6c6f3c1" --profile prod; aws route53 create-vpc-association-authorization --hosted-zone-id "Z022622321HG7G07ECKFC" --vpc "VPCRegion=eu-west-1,VPCId=vpc-08556c49da6c6f3c1" --profile stage'
    }
}

resource "aws_route53_zone_association" "stagetoprod" {
  zone_id = "${aws_route53_zone.a2i-stage.zone_id}"
  vpc_id  = "08556c49da6c6f3c1"
}

resource "aws_route53_zone_association" "infratoprod" {
  zone_id = "${aws_route53_zone.a2i-infra.zone_id}"
  vpc_id  = "08556c49da6c6f3c1"
}



data "aws_route53_zone" "hyke" {
  name         = "hyke.ai."
  private_zone = false
}

data "aws_route53_zone" "hykeapi" {
  name         = "hyke.ae."
  private_zone = false
}
*/
