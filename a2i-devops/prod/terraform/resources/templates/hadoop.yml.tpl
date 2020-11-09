---
- name: hadoop
  hosts: hadoop
  remote_user: ubuntu
  become: yes

  pre_tasks:
  - name: Execute the script for mounting device
    script: ../scripts/mount_device.sh

  roles:
  - ldap-agent
  - node-exporter

  vars:
    service_name : "${service_name}"
    dns_name_of_server : "${dns_name_of_server}"
