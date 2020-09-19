---

################## Ansible play for node infra_tools #####################

- name: Install and configure infra tools like zk-server and CA-server
  hosts: infra_tools
  remote_user: ubuntu
  become: yes
  pre_tasks:
  - name: Execute the script for mounting device
    script: ../scripts/mount_device.sh

  roles:
  - java
  - nifi-toolkit
  - zookeeper
  - install_env
  - filebeat
  - node-exporter

  vars:
    service_name             : "${service_name}"
    zk_server_id             : "${zk_server_id}"
    env_dns                  : "${env_dns}"
    is_ca_server             : "${is_ca_server}"
    ca_server_dn             : "${ca_server_dn}"
    ca_server_hostname       : "${ca_server_hostname}"
    dns_name_of_server       : "${dns_name_of_server}"
