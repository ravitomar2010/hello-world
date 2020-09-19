---
- name: ldap_server
  hosts: ldap_server
  remote_user: ubuntu
  become: yes

#  pre_tasks:
#  - name: Execute the script for mounting device
#    script: ../scripts/mount_device.sh

  roles:
  - ldap-server
  - install_env
  - apache2
  - filebeat
  - node-exporter

  vars:
    openldap_server_domain_name: "${openldap_server_domain_name}"
    ldap_dn: "${ldap_dn}"
    openldap_server_rootuserpath_ssm: "${openldap_server_rootuserpath_ssm}"
    service_name : "${service_name}"
    dns_name_of_server : "${dns_name_of_server}"
