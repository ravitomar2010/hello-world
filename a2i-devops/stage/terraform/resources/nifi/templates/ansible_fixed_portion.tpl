resource "local_file" "nifi_inventory_file_replace_me_ts" {
  depends_on = [ aws_eip.pritunl, module.nifi ]
  content     = data.template_file.nifi_hosts.rendered
  filename = "${path.module}/../../ansible/hosts/nifi_hosts"
}

resource "local_file" "nifi_roles_tmp_replace_me_ts" {
  depends_on = [ aws_eip.pritunl, module.pritunl, local_file.ssh_cfg ]
  content     = data.template_file.nifi_ansible_role.rendered
  filename = "${path.module}/nifi.yaml"
}

resource "null_resource" "prepare_final_yaml_replace_me_ts" {
  depends_on = [ local_file.nifi_roles_tmp_replace_me_ts, aws_eip.pritunl, module.nifi ]
  provisioner "local-exec" {
    command = "${path.module}/nifi/prepare_final_yaml.sh"
  }
}

data "local_file" "ansible_role_template_replace_me_ts" {
  filename = "${path.module}/nifi.yaml"
  depends_on = [null_resource.prepare_final_yaml_replace_me_ts]
}

data "template_file" "nifi_ansible_role_final_replace_me_ts" {
  template = data.local_file.ansible_role_template_replace_me_ts.content
  depends_on = [ local_file.nifi_roles_tmp_replace_me_ts, null_resource.prepare_final_yaml_replace_me_ts, aws_eip.pritunl, module.nifi ]
}

resource "local_file" "nifi_roles_replace_me_ts" {
  depends_on = [ aws_eip.pritunl, module.pritunl, local_file.ssh_cfg, data.template_file.nifi_ansible_role_final_replace_me_ts  ]
  content     = data.template_file.nifi_ansible_role_final_replace_me_ts.rendered
  filename = "${path.module}/../../ansible/plays/nifi.yaml"
}

resource "null_resource" "nifi_ansible_replace_me_ts" {
  depends_on = [ local_file.nifi_inventory_file_replace_me_ts, local_file.nifi_roles_replace_me_ts, aws_eip.pritunl, module.nifi,  module.infra_tools ]
  provisioner "local-exec" {
    command = "sleep 30; cd ${path.module}/../../ansible; ansible-playbook -i hosts/nifi_hosts plays/nifi.yaml"
  }
}

resource "null_resource" "cleanup" {
  depends_on = [ null_resource.nifi_ansible_replace_me_ts ]
  provisioner "local-exec" {
    command = "rm -rf ./nifi.yaml;"
  }
}
