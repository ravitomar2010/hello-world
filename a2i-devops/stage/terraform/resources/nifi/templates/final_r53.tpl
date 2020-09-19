
######################### Route 53 for main nifi url #################################

resource "aws_route53_record" "r53-main-nifi" {
  zone_id = "${aws_route53_zone.a2i-replace_me_env.zone_id}"
  name    = "nifi"
  type    = "A"
  ttl     = "300"
