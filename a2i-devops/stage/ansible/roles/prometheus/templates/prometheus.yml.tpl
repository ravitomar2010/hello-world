################################################################################
##   node exporter job for service_name
################################################################################

- job_name: 'service_name_node_exporter'
  scrape_interval: 5s
  static_configs:
          - targets: ['dns_name_of_server:9100']
