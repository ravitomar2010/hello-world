- job_name: '{{ service_name }}_node_exporter'
  scrape_interval: 5s
  static_configs:
          - targets: '[{{ ip_address_of_node }}:9100]'
