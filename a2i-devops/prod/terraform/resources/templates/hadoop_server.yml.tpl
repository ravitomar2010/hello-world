---
- name: hadoop_server
  hosts: hadoop_server
  remote_user: ubuntu
  become: yes

  roles:
  - ldap-agent
  - file-beat
  - node-exporter

  vars:
    service_name : "${service_name}"
    dns_name_of_server : "${dns_name_of_server}"
