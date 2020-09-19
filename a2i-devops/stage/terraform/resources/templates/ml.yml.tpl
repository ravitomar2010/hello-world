---
- name: ml
  hosts: ml
  remote_user: ubuntu
  become: yes

  pre_tasks:
  - name: Execute the script for mounting device
    script: ../scripts/mount_device.sh

  roles:
  - install_env
  - filebeat
  - node-exporter
  - ldap-agent

  vars:
    service_name : "${service_name}"
    dns_name_of_server : "${dns_name_of_server}"
