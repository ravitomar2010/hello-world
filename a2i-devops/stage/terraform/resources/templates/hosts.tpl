[${tool}]
%{ for private_ip in host_private_ips ~}
${private_ip}   ansible_ssh_private_key_file=${pem_path}
%{ endfor ~}