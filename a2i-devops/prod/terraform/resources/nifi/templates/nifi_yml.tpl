- name: Install and configure nifi for node {replace_me}
  hosts: {replace_me}
  remote_user: ubuntu
  become: yes
  pre_tasks:
  - name: Execute the script for mounting device
    script: ../scripts/mount_device.sh

  roles:
  - java
  - nginx
  - nifi
  - install_env
  - filebeat
  - node-exporter

  vars:
    # ldap related variables
    ldap:
      manager_dn                          : "${manager_dn}"
      url                                 : "${url}"
      user_search_base                    : "${user_search_base}"
      user_filter                         : "${user_filter}"
      group_search_base                   : "${group_search_base}"
      node_identity_cn                    : "${node_identity_cn}"
      initial_admin_id                    : "${initial_admin_id}"
    nifi:
      hostname_{replace_me}               : "${dns_name_of_server_{replace_me}}"
      server_id                           : "replace_me_server_id"
    nifi_binduserpath_ssm                 : "${nifi_binduserpath_ssm}"
    iscleanupneeded_{replace_me}          : "${iscleanupneeded_{replace_me}}"
    service_name_{replace_me}             : "${service_name_{replace_me}}"
    dns_name_of_server_{replace_me}       : "${dns_name_of_server_{replace_me} }"
