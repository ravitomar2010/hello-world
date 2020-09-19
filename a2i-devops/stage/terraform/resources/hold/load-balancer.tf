#######################################Public ALB#####################################


module "public_alb_security_group" {
  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-public-alb-${local.environment}-"
  description = "Security Group for Public application load balancer"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["${local.variables[terraform.workspace].vpc_cidr}"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "Ingress for HTTP traffic allowed from internet"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Ingress for HTTP traffic allowed from internet"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 555
      to_port     = 555
      protocol    = "tcp"
      description = "Ingress for 555 traffic allowed from internet"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 3003
      to_port     = 3003
      protocol    = "tcp"
      description = "Ingress for API traffic allowed from internet"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 0
      to_port     = 65535
      protocol    = "all"
      description = "Ingress for all traffic within VPC"
      cidr_blocks = local.variables[terraform.workspace].vpc_cidr
    }
  ]
  egress_rules        = ["all-all"]
}

module "public-alb" {
  source  = "../modules/terraform-aws-alb"

  name = "${var.platform}-public-alb-${local.environment}"

  load_balancer_type = "application"

  vpc_id          = module.vpc.vpc_id
  security_groups = [module.public_alb_security_group.this_security_group_id]
  subnets         = tolist(module.vpc.public_subnets)

  //  # See notes in README (ref: https://github.com/terraform-providers/terraform-provider-aws/issues/7987)
  //  access_logs = {
  //    bucket = module.log_bucket.this_s3_bucket_id
  //  }

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    },
  ]

  https_listeners = [
    {
      port               = 443
      protocol           = "HTTPS"
      certificate_arn    = module.certificate-1.this_acm_certificate_arn
      target_group_index = 1
    },
  ]

  target_groups = [
    {
      name                 = "default-tg-public"
      #name_prefix          = ""
      backend_protocol     = "HTTPS"
      backend_port         = 443
      target_type          = "instance"
      deregistration_delay = 10
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/healthz"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTPS"
        matcher             = "200-399"
      }
    },
    //{
    //  name_prefix                        = "l1-"
    //  target_type                        = "lambda"
    //  lambda_multi_value_headers_enabled = true
    //},
  ]

  tags = {
    "Environment"  = local.environment
    "Application"  = "load_balancer"
    "Name"         = "${var.platform}-public-alb-${local.environment}"
  }
}

resource "aws_route53_record" "public-alb" {
  zone_id = "{aws_route53_zone.a2i-stage.zone_id}"
  name    = "public-alb-${local.environment}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${module.public-alb.this_lb_dns_name}"]
}


#######################################Private ALB#####################################



module "private_alb_security_group" {
  source  = "../modules/terraform-aws-security-group"

  name        = "${var.platform}-private-alb-${local.environment}-"
  description = "Security Group for Private application load balancer"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["${local.variables[terraform.workspace].vpc_cidr}"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "Ingress for HTTP traffic allowed from internet"
      cidr_blocks = "10.0.0.0/8,172.27.0.0/16"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Ingress for HTTP traffic allowed from internet"
      cidr_blocks = "10.0.0.0/8,172.27.0.0/16"
    },
    {
      from_port   = 555
      to_port     = 555
      protocol    = "tcp"
      description = "Ingress for 555 traffic allowed from internet"
      cidr_blocks = "10.0.0.0/8,172.27.0.0/16"
    },
    {
      from_port   = 3003
      to_port     = 3003
      protocol    = "tcp"
      description = "Ingress for API traffic allowed from internet"
      cidr_blocks = "10.0.0.0/8,172.27.0.0/16"
    },
    {
      from_port   = 0
      to_port     = 65535
      protocol    = "all"
      description = "Ingress for all traffic within VPC"
      cidr_blocks = local.variables[terraform.workspace].vpc_cidr
    }
  ]
  egress_rules        = ["all-all"]
}

module "private-alb" {
  source  = "../modules/terraform-aws-alb"

  name = "${var.platform}-private-alb-${local.environment}"

  load_balancer_type = "application"

  vpc_id          = module.vpc.vpc_id
  security_groups = [module.private_alb_security_group.this_security_group_id]
  subnets         = tolist(module.vpc.private_subnets)

  //  # See notes in README (ref: https://github.com/terraform-providers/terraform-provider-aws/issues/7987)
  //  access_logs = {
  //    bucket = module.log_bucket.this_s3_bucket_id
  //  }

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    },
  ]

  https_listeners = [
    {
      port               = 443
      protocol           = "HTTPS"
      certificate_arn    = module.certificate-1.this_acm_certificate_arn
      target_group_index = 1
    },
  ]

  target_groups = [
    {
      name                 = "default-tg-private"
      #name_prefix          = ""
      backend_protocol     = "HTTPS"
      backend_port         = 443
      target_type          = "instance"
      deregistration_delay = 10
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/healthz"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTPS"
        matcher             = "200-399"
      }
    },
    /*{
      name_prefix                        = "l1-"
      target_type                        = "lambda"
      lambda_multi_value_headers_enabled = true
    },*/
  ]

  tags = {
    "Environment"  = local.environment
    "Application"  = "load_balancer"
    "Name"         = "${var.platform}-private-alb-${local.environment}"
  }
}

resource "aws_route53_record" "private-alb" {
  zone_id = "{aws_route53_zone.a2i-stage.zone_id}"
  name    = "private-alb-${local.environment}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${module.private-alb.this_lb_dns_name}"]
}
