---
- name: data-application
  hosts: data-application
  remote_user: ubuntu
  become: yes

  pre_tasks:
  - name: Execute the script for mounting device
    script: ../scripts/mount_device.sh

  roles:
  - ldap-agent
  - filebeat
  - node-exporter
  - apache

  vars:
    service_name : "${service_name}"
    dns_name_of_server : "${dns_name_of_server}"
