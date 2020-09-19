---
- name: prometheus
  hosts: prometheus
  remote_user: ubuntu
  become: yes
#  pre_tasks:
#  - name: Execute the script for mounting device
#    script: ../scripts/mount_device.sh

  roles:
  - java
  - zookeeper
  - prometheus
  - install_env
  - apache2
  - filebeat
  - node-exporter

  vars:
    service_name            : "${service_name}"
    dns_name_of_server      : "${dns_name_of_server}"
    zk_server_id            : '${zk_server_id}'
    env_dns                 : '${env_dns}'
