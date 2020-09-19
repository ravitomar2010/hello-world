---
- name: grafana
  hosts: grafana
  remote_user: ubuntu
  become: yes

  pre_tasks:
  - name: Execute the script for mounting device
    script: ../scripts/mount_device.sh

  roles:
  - grafana
  - install_env
  - filebeat
  - node-exporter

  vars:
    service_name : "${service_name}"
    dns_name_of_server : "${dns_name_of_server}"
    grafana_server_rootdbuserpath_ssm : "${grafana_server_rootdbuserpath_ssm}"