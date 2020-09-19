---
- name: zk-server
  hosts: zk-server
  remote_user: ubuntu
  become: yes

  roles:
  - java
  - zookeeper
  - install_env
  - filebeat
  - node-exporter

  vars:
    zk_version              : '${zk_version}'
    zk_server_id            : '${zk_server_id}'
    env_dns                 : '${env_dns}'
    service_name            : "${service_name}"
    dns_name_of_server      : "${dns_name_of_server}"
