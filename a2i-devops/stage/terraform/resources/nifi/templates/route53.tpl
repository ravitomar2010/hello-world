
######################### Route 53 for node replace_me_node #################################

resource "aws_route53_record" "r53replace_me_node" {
  zone_id = "${aws_route53_zone.a2i-replace_me_env.zone_id}"
  name    = "replace_me_node"
  type    = "A"
  ttl     = "300"
  records = ["${module.nifi.private_ip[replace_me_var_node_count]}"]
}
