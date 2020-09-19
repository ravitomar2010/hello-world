---
- name: pritunl
  hosts: pritunl
  remote_user: ubuntu
  become: yes

  pre_tasks:
  - name: Execute the script for mounting device
    script: ../scripts/mount_device.sh

  roles:
  - install_env
  - pritunl
  - filebeat
  # - node-exporter

  vars:
    vault_password: ${vault_password}
    service_name : "${service_name}"
    dns_name_of_server : "${dns_name_of_server}"
