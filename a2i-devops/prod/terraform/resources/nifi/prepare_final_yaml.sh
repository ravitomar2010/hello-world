#!/bin/sh

filename='./nifi/node_list.txt'

cat ./nifi.yaml > tmp_nifi.yaml
node_count=1
while read line; do
  sed "s/dns_name_of_server_nifi_$node_count/dns_name_of_server/g" tmp_nifi.yaml > tmp_nifi1.yaml
  sed "s/service_name_nifi_$node_count/service_name/g" tmp_nifi1.yaml > tmp_nifi2.yaml
  sed "s/hostname_nifi_$node_count/hostname/g" tmp_nifi2.yaml > tmp_nifi3.yaml
  sed "s/iscleanupneeded_nifi_$node_count/iscleanupneeded/g" tmp_nifi3.yaml > tmp_nifi4.yaml
  ((node_count++))
  cat tmp_nifi4.yaml > tmp_nifi.yaml
done < $filename

cat tmp_nifi.yaml > ./nifi.yaml

##cleanup

rm -rf tmp_nifi.yaml
rm -rf tmp_nifi1.yaml
rm -rf tmp_nifi2.yaml
rm -rf tmp_nifi3.yaml
rm -rf tmp_nifi4.yaml
