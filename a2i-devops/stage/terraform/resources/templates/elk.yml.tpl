---
- name: elk
  hosts: elk
  remote_user: ubuntu
  become: yes

  pre_tasks:
  - name: Execute the script for mounting device
    script: ../scripts/mount_device.sh

  roles:
  - install_env
  - elk
  - zookeeper
  - filebeat
  - node-exporter

  vars:
    aws_region: ${aws_ec2_region}
    environment: ${environment}
    platform: ${platform}
    service_name : "${service_name}"
    dns_name_of_server : "${dns_name_of_server}"
    zk_server_id  : "${zk_server_id}"
