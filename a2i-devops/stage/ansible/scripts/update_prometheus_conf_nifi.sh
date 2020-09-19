#!/bin/bash

script_dir="/root/scripts/update_prometheus_conf/"
service_name=$1
dns_name_of_server=$2

cp "$script_dir"prometheus.yml.tpl "$script_dir"prometheus.yml.tpl.tmp

echo "Replacing service_name in configuration file"

sed 's|service_name|'"${service_name}"'|g' "$script_dir"prometheus.yml.tpl.tmp > "$script_dir"prometheus.yml.inter.tmp

echo "Replacing DNS_name in conf file"

sed 's|dns_name_of_server|'"${dns_name_of_server}"'|g' "$script_dir"prometheus.yml.inter.tmp > "$script_dir"prometheus.yml.final.tmp

echo "check if configuration file already has the entry"

if grep -q "$dns_name_of_server:9100" "/etc/prometheus/prometheus.yml"; then
        echo "configuration file already has this entry"
else
        echo "Appending the actual configuration file"
        cat "$script_dir"prometheus.yml.final.tmp >> /etc/prometheus/prometheus.yml
        sudo service prometheus restart
fi

echo "Removing all the temp files created"

rm -rf "$script_dir"/*.tmp
