
############################## ########### ####################################
##############################     IAM     ####################################
############################## ########### #################################### 

data "template_file" "nifi_assume_role_cfg" {
  template = "${file("${path.module}/templates/assumerole_ec2.tpl")}"
}

resource "aws_iam_instance_profile" "nifi_profile" {
  name = "nifi_profile"
  role = "${aws_iam_role.nifi_role.name}"
}

resource "aws_iam_role" "nifi_role" {
  name = "nifi_role"
  assume_role_policy = data.template_file.nifi_assume_role_cfg.rendered
  tags = {
    "Environment" = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "nifi_attach" {
  role       = "${aws_iam_role.nifi_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}
