![Logo](https://blog.drumup.io/wp-content/uploads/2017/02/ioHfqHA.gif)
# Ansible Role: Nginx

Installs Nginx on Debian/Ubuntu servers.

- [Getting Started](#getting-started)
  - [Installation](#installation)
- [Dependencies](#dependencies)
- [Variables](#variables)
- [Usage](#usage)

## Getting Started

These instructions will get you a copy of the role for your ansible playbook. Once launched, This role installs the latest version of Nginx from the Nginx apt on Debian-based systems). You will likely need to do extra setup work after this role has installed Nginx, like adding your own [virtualhost].conf file inside `/etc/nginx/conf.d/`, describing the location and options to use for your particular website.

## Installation
Using `git`:

```shell
$ git clone https://gitlab.intelligrape.net/devops/devops-e2e/ansible/roles/nginx nginx
```

## Dependencies

* Ansible >= 2.8.0.0
* Inventory destination should be a Debian environment.

## Variables
None

## Usage

    - name: nginx
      hosts: server
      remote_user: ubuntu
      become: yes
      roles:
        - nginx