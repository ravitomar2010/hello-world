---

################## Nifi play for node nifi_1 #####################

- name: Install and configure nifi for node nifi_1
  hosts: nifi_1
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
      hostname_nifi_1               : "${dns_name_of_server_nifi_1}"
      server_id                           : "1"
    nifi_binduserpath_ssm                 : "${nifi_binduserpath_ssm}"
    iscleanupneeded_nifi_1          : "${iscleanupneeded_nifi_1}"
    service_name_nifi_1             : "${service_name_nifi_1}"
    dns_name_of_server_nifi_1       : "${dns_name_of_server_nifi_1 }"


################## Nifi play for node nifi_2 #####################

- name: Install and configure nifi for node nifi_2
  hosts: nifi_2
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
      hostname_nifi_2               : "${dns_name_of_server_nifi_2}"
      server_id                           : "2"
    nifi_binduserpath_ssm                 : "${nifi_binduserpath_ssm}"
    iscleanupneeded_nifi_2          : "${iscleanupneeded_nifi_2}"
    service_name_nifi_2             : "${service_name_nifi_2}"
    dns_name_of_server_nifi_2       : "${dns_name_of_server_nifi_2 }"


################## End of node Plays #####################
