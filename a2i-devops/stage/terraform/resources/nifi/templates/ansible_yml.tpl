
data "template_file" "nifi_ansible_role" {
  template = "${file("${path.module}/templates/nifi.yml.tpl")}"
  vars = {
        manager_dn              : "${local.variables[terraform.workspace].ec2.nifi.manager_dn}"
        url                     : "${local.variables[terraform.workspace].ec2.nifi.ldap_url}"
        user_search_base        : "${local.variables[terraform.workspace].ec2.nifi.user_search_base}"
        user_filter             : "${local.variables[terraform.workspace].ec2.nifi.user_filter}"
        group_search_base       : "${local.variables[terraform.workspace].ec2.nifi.group_search_base}"
        node_identity_cn        : "${local.variables[terraform.workspace].ec2.nifi.node_identity_cn}"
        initial_admin_id        : "${local.variables[terraform.workspace].ec2.nifi.initial_admin_id}"
        nifi_binduserpath_ssm   : "${local.variables[terraform.workspace].ec2.nifi.binduserpath_ssm}"
