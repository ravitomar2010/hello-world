Host ${pritunl_public_ip}
    User                   ubuntu
    HostName               ${pritunl_public_ip}
    ProxyCommand           none
    IdentityFile           ${jump_pem_path}
    BatchMode              yes
    PasswordAuthentication no
    StrictHostKeyChecking  no


Host ${infra_hosts}
    ServerAliveInterval    60
    TCPKeepAlive           yes
    ProxyCommand           ssh -F ./ssh.cfg -q -A ubuntu@${pritunl_public_ip} nc %h %p
    ControlMaster          auto
    ControlPath            ~/.ssh/mux-%r@%h:%p
    ControlPersist         8h
    User                   ubuntu
    IdentityFile           ${infra_private_pem_path}
    StrictHostKeyChecking  no


Host ${stage_hosts}
    ServerAliveInterval    60
    TCPKeepAlive           yes
    ProxyCommand           ssh -F ./ssh.cfg -q -A ubuntu@${pritunl_public_ip} nc %h %p
    ControlMaster          auto
    ControlPath            ~/.ssh/mux-%r@%h:%p
    ControlPersist         8h
    User                   ubuntu
    IdentityFile           ${stage_private_pem_path}
    StrictHostKeyChecking  no
