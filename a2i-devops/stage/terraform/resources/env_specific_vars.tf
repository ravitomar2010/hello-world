locals {
  variables ={
    prod = {
      vpc_cidr = "10.11.0.0/16"
      ec2 = {
        emr = {
          type = "t3.large"
        }
        elasticsearch = {
          count = 1
          type = "t3.large"
          service_name : "elasticsearch"
        }
        kibana = {
          type = "t3.large"
        }
        pritunl = {
          type = "t3.large"
        }
        jenkins = {
          type = "t3.large"
          shared_library_repo = "https://git-codecommit.eu-west-1.amazonaws.com/v1/repos/a2i-shared-libraries"
          shared_library_name = "a2i-shared-libraries"
          shared_library_default_version = "master"
          onboard_job_repo = "https://bitbucket.org/axiomtelecom/hyke-simple-service.git"
          onboard_job_configure_branch = "dev"

        }
        ldap_server = {
          type = "t2.micro"
          openldap_server_domain_name = "a2i.infra"
          ldap_dn = "ou=groups,dc=a2i,dc=infra"
        }
      }
      elasticache = {
        redis = {
          nodes        = "1"
          node_type    = "cache.t3.medium"
          redis_shards = "2"
          auth_token   = "ASAKEs6kdjakloa27G"
        }
      }
    }//prod
    stage = {
      transit_gateway_id = "tgw-022cabd543efb2c4b"
      vpc_cidr = "10.12.0.0/16"
      ec2 = {
        hadoop = {
          type = "t3.small"
          service_name : "hadoop"
        }
        ml ={
          type = "t3.small"
          service_name : "ml"
        }
        nifi = {
          ldap_url            =   "ldap://ldap.a2i.infra:389"
          manager_dn          =   "uid=ldap,dc=a2i,dc=infra"
          user_search_base    =   "ou=users,dc=a2i,dc=infra"
          user_filter         =   "cn={0}"
          group_search_base   =   "ou=groups,dc=a2i,dc=infra"
          node_identity_cn    =   "cn=nifi.a2i.stage,dc=a2i,dc=infra"
          initial_admin_id    =   "nifi-admin"
          binduserpath_ssm    =   "/a2i/infra/ldap/bindpwd"
          type                =   "t3.large"
          service_name        =   "nifi"
        }
        nifi-registry = {
          ldap_url            =   "ldap://ldap.a2i.infra:389"
          manager_dn          =   "uid=ldap,dc=a2i,dc=infra"
          user_search_base    =   "ou=users,dc=a2i,dc=infra"
          user_filter         =   "cn={0}"
          group_search_base   =   "ou=groups,dc=a2i,dc=infra"
          node_identity_cn    =   "cn=*.a2i.stage,dc=a2i,dc=infra"
          initial_admin_id    =   "nifi-admin"
          type                            =   "t3.micro"
          service_name                    =   "nifi-registry"
          nifi_registry_git_user_ssm_path =   "/a2i/git/nifi_registry/passwd"
        }
        elk = {
          count = 1
          type = "t3.xlarge"
          service_name : "elk"
          zk_server_id  = "3"
          env_dns       = "a2i.infra"
        }
        infra_tools = {
          type                : "t3.small"
          service_name        : "infra-tools"
          zk_server_id        : 1
          env_dns             : "a2i.infra"
          is_ca_server        : "true"
          ca_server_dn        : "cn=ca-server.a2i.infra,ou=users,dc=a2i,dc=infra"
          ca_server_hostname  : "ca-server.a2i.infra"
          dns_name_of_server  : "infra-tools.a2i.infra"
        }
        apps = {
          count = 1
          type = "t3.small"
          service_name : "apps"
        }
        kibana = {
          type = "t3.small"
          service_name : "kibana"
        }
        pritunl = {
          type = "t3.small"
          service_name : "vpn"
        }
        prometheus = {
          type          = "t3.small"
          service_name  = "prometheus"
          zk_server_id  = "2"
          env_dns       = "a2i.stage"
        }
        jenkins = {
          type                            = "t3.xlarge"
          shared_library_repo             = "https://git-codecommit.eu-west-1.amazonaws.com/v1/repos/a2i-shared-libraries"
          shared_library_name             = "hyke-devops-libs"
          shared_library_default_version  = "master"
          onboard_job_repo                = "https://bitbucket.org/axiomtelecom/hyke-simple-service.git"
          onboard_job_configure_branch    = "dev"
          service_name                    = "jenkins"
          extraEBSsize                    = 50
        }
        ldap_server = {
          type                              = "t3.micro"
          openldap_server_domain_name       = "a2i.infra"
          ldap_dn                           = "ou=groups,dc=a2i,dc=infra"
          openldap_server_rootuserpath_ssm  = "/a2i/infra/ldap/rootpwd"
          service_name                      = "ldap"
        }
        grafana ={
            type                              = "t3.small"
            service_name                      = "grafana"
            grafana_server_rootdbuserpath_ssm = "/a2i/infra/grafana/rootdbpassword"
        }
        zk-server = {
            type                    : "t3.nano"
            zk_version              : "apache-zookeeper-3.5.6-bin"
            zk_server_id            : "1"
            env_dns                 : "a2i.stage"
            service_name            : "zk-server"
            dns_name_of_server      : "zk-server"
        }
      }
      elasticache = {
        redis = {
          nodes        = "1"
          node_type    = "cache.t3.medium"
          redis_shards = "2"
          auth_token   = "ASAKEs6kdjakloa27G"
        }
      }
    }//stage
  }
}

locals {
  environment = "${terraform.workspace}"
}
