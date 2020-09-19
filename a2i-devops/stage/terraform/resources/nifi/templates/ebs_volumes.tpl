
###### EBS resource for replace_me_node

resource "aws_ebs_volume" "replace_me_node-first" {

  depends_on           	= [module.nifi]
  availability_zone     = "${module.nifi.availability_zone[0]}"
  size                  = 1
  type                  = "gp2"
  tags 			            = {
			                         Name	= "replace_me_node-first-ebs-storage"
  			                  }
}

resource "aws_volume_attachment" "replace_me_node_att" {

  device_name   = "/dev/xvdb"
  volume_id     = "${aws_ebs_volume.replace_me_node-first.id}"
  instance_id   = "${module.nifi.id[replace_me_var_node_count]}"

}
