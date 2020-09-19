# Ansible Role: Nexus 3

This ansible role installs Latest pritunl, mongodb printunl backend on debian environment. Once installed it configiure admin credentials and encrypt it using ansible Vault.

- [Getting Started](#getting-started)
  - [Installation](#installation)
- [Dependencies](#dependencies)
- [Variables](#variables)
  - [General Variables](#general-variables)
- [Usage](#usage)

## Getting Started

These instructions will get you a copy of the role for your ansible playbook. Once launched, it will install a Printunl VPN server in a Debian system.

## Installation
Using `git`:

```shell
$ git clone https://gitlab.intelligrape.net/devops/devops-e2e/ansible/roles/pritunl-vpn pritunl-vpn
```

## Dependencies

* Ansible >= 2.8.0.0
* Inventory destination should be a Debian environment.


## Variables
Ansible variables, along with the default values. see [defaults](defaults/main.yml) :

### General variables
```yaml
    vault_directory: /etc
```

## Usage

    - name: pritunl-vpn
      hosts: server
      remote_user: ubuntu
      become: yes
      roles:
        - pritunl-vpn

![Logo](https://static.wixstatic.com/media/567ffc_212d142561994cbab523acc794db43ee~mv2.gif)
