---
- name: nifi_registry
  hosts: nifi_registry
  remote_user: ubuntu
  become: yes
  pre_tasks:
  - name: Execute the script for mounting device
    script: ../scripts/mount_device.sh

  roles:
  - java
  - nginx
  - nifi-toolkit
  - nifi-registry
  - install_env
  - filebeat
  - node-exporter

  vars:
    service_name                : "${service_name}"
    dns_name_of_server          : "${dns_name_of_server}"
    nifi_registry_git_user_ssm  : ${nifi_registry_git_user_ssm}
