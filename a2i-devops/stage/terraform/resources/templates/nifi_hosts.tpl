## List of all the nifi hosts 

[nifi] 

${nifi_private_ip_nifi-1} ansible_ssh_private_key_file=${private_pem_path} 

${nifi_private_ip_nifi-2} ansible_ssh_private_key_file=${private_pem_path} 

## List of nifi hosts for nifi
[nifi_1]
${nifi_private_ip_nifi-1} ansible_ssh_private_key_file=${private_pem_path} 

[nifi_2]
${nifi_private_ip_nifi-2} ansible_ssh_private_key_file=${private_pem_path} 

