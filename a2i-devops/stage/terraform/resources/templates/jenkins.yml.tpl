---
- name: jenkins
  hosts: jenkins
  remote_user: ubuntu
  become: yes

  pre_tasks:
  - name: Execute the script for mounting device
    script: ../scripts/mount_device.sh

  roles:
  - install_env
  - java
  - jenkins
  - filebeat
  - node-exporter

  vars:
    shared_library_repo: "${shared_library_repo}"
    shared_library_name: "${shared_library_name}"
    shared_library_default_version: "${shared_library_default_version}"
    onboard_job_repo: "${onboard_job_repo}"
    onboard_job_configure_branch: "${onboard_job_configure_branch}"
    service_name : "${service_name}"
    dns_name_of_server : "${dns_name_of_server}"
