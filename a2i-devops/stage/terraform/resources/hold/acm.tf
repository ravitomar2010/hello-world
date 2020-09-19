module "certificate-stage" {
  source = "../modules/terraform-aws-acm"

  domain_name = var.stage_dns
  zone_id     = "${aws_route53_zone.a2i-stage.zone_id}"

  subject_alternative_names = [
    "*.${var.infra_dns}",
  ]

  wait_for_validation = false # true

  tags = {
    "Environment"  = local.environment
    "Application"  = "ACM"
    "Name"         = "${var.platform}-acm-${local.environment}"
  }
}
