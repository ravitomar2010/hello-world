#!/bin/sh

## Flow to create hosts file

filename='node_list.txt'

##Get env

env=$(cd ..;terraform workspace show;cd -;)
env=$(echo $env | awk '{print $1;}')
#echo "Env is "$env

#${nifi_private_ip_}   ansible_ssh_private_key_file=${private_pem_path}

## Create a temp file to hold initial template for hosts file

rm -rf tmp_all_hosts.txt
rm -rf tmp_hosts.txt

touch tmp_all_hosts.txt
touch tmp_hosts.txt

## Add all hosts entry in all hosts file
echo "## List of all the nifi hosts \n" >> tmp_all_hosts.txt
echo "[nifi] \n" >> tmp_all_hosts.txt
echo "## List of nifi hosts for nifi" >> tmp_hosts.txt
node_count=1
while read line; do
	#cp ./s3_private.tpl ./$line.tf-tmp
	#sed "s/replace_me_name/$line/g" $line.tf-tmp >> s3.tf
	#rm -rf $line.tf-tmp
  #firstemptyline= grep -n '^$' tmp_hosts.txt | head -n 1 | tr -d :
  #echo "Empty line is "$firstemptyline
  line1=$(echo "$line" | tr - _ )
  echo '${nifi_private_ip_'$line'} ansible_ssh_private_key_file=${private_pem_path} \n' >> tmp_all_hosts.txt
  echo "["$line1"]" >> tmp_hosts.txt
  echo '${nifi_private_ip_'$line'} ansible_ssh_private_key_file=${private_pem_path} \n' >> tmp_hosts.txt
  #echo " nodes are"$line
done < $filename

cat tmp_hosts.txt >> tmp_all_hosts.txt

## Copy final nifi.hosts.tpl file to templates folder
mv tmp_all_hosts.txt ../templates/nifi_hosts.tpl

## Flow to create nifi.yml file

## Create temporary nifi.tpl file
rm -rf tmp_nifi_tpl.txt
touch tmp_nifi_tpl.txt
echo '---\n' >> tmp_nifi_tpl.txt

node_count=1
while read line; do

  line1=$(echo "$line" | tr - _ )
  echo "################## Nifi play for node "$line1" #####################\n" >> tmp_nifi_tpl.txt
  sed "s/{replace_me}/$line1/g" ./templates/nifi_yml.tpl > tmp_nifi_tpl1.txt
  sed "s/replace_me_server_id/$node_count/g" tmp_nifi_tpl1.txt >> tmp_nifi_tpl.txt
  echo "\n" >> tmp_nifi_tpl.txt
  ((node_count++))
done < $filename

echo "################## End of node Plays #####################" >> tmp_nifi_tpl.txt

## Copy final nifi.yml.tpl file to templates folder
mv tmp_nifi_tpl.txt ../templates/nifi.yml.tpl


## Flow to create nifi.tf file

## Create temporary nifi.tf file
rm -rf tmp_nifi_tf.txt
touch tmp_nifi_tf.txt

## get the no of nodes in desired nifi cluster.
no_of_nodes=$(< "node_list.txt" wc -l)
#no_of_nodes= echo $no_of_nodes | tr -d [:space]
#echo "The no of desired hosts are "$no_of_nodes

## Add security group resource from template
cat ./templates/security_group.tpl >> tmp_nifi_tf.txt

sed "s/{replace_me_node_count}/$no_of_nodes/g" ./templates/ec2_instance.tpl >> tmp_nifi_tf.txt

##Add EBS resources from templates
rm -rf tmp_ebs_tpl.txt
touch tmp_ebs_tpl.txt

echo "############################## ########### #################################### " >> tmp_ebs_tpl.txt
echo "############################## EBS Volumes #################################### " >> tmp_ebs_tpl.txt
echo "############################## ########### #################################### " >> tmp_ebs_tpl.txt

node_count=0
while read line; do
  touch tmp_ebs_1.txt
  sed "s/replace_me_node/$line/g" ./templates/ebs_volumes.tpl >> tmp_ebs_1.txt
  sed "s/replace_me_var_node_count/$node_count/g" tmp_ebs_1.txt >> tmp_ebs_tpl.txt
  ((node_count++))
  rm -rf tmp_ebs_1.txt
done < $filename

cat tmp_ebs_tpl.txt >> tmp_nifi_tf.txt

## Add IAM resources from template

cat ./templates/iam.tpl >> tmp_nifi_tf.txt

## Add Ansible resources from template

## Hosts file
node_count=0

rm -rf tmp_hosts_var.txt
cat ./templates/ansible_hosts_vars.tpl >> tmp_hosts_var.txt
while read line; do

  echo "            nifi_private_ip_"$line "=  module.nifi.private_ip[$node_count]" >> tmp_hosts_var.txt
  ((node_count++))
done < $filename

## Dont modify the space otherwise format issues might occure
    echo  '            private_pem_path       =  "${var.ec2_private_pem_path}${var.'$env'_private_keypair}.pem"' >> tmp_hosts_var.txt
    echo "            } \n} " >> tmp_hosts_var.txt

cat tmp_hosts_var.txt >> tmp_nifi_tf.txt

## yml file
node_count=0

rm -rf tmp_yml_var.txt
cat ./templates/ansible_yml.tpl >> tmp_yml_var.txt

while read line; do
  rm -rf tmp1.txt
  line1=$(echo "$line" | tr - _ )
  echo '        iscleanupneeded_'$line1'       : "false"' >> tmp1.txt
  echo '        node_identity_'$line1'         : "'$line'.${var.'$env'_dns}"' >> tmp1.txt
  echo '        service_name_'$line1'          : "'$line'"'>> tmp1.txt
  echo '        dns_name_of_server_'$line1'    : "'$line'.${var.'$env'_dns}"' >> tmp1.txt
  cat tmp1.txt >> tmp_yml_var.txt
done < $filename

echo "            } \n} " >> tmp_yml_var.txt

cat tmp_yml_var.txt >> tmp_nifi_tf.txt


##Create and replace ts in task definition
date_to_replace=$(date '+%Y_%m_%d_%H_%M_%S')
echo "Date is "$date_to_replace

sed "s/replace_me_ts/$date_to_replace/g" ./templates/ansible_fixed_portion.tpl > tmp_ansible_fixed_portion.txt
cat tmp_ansible_fixed_portion.txt >> tmp_nifi_tf.txt

## route 53 entries

node_count=0

rm -rf tmp_r53_tpl.txt
touch tmp_r53_tpl.txt

echo "############################## ########### #################################### " >> tmp_r53_tpl.txt
echo "##############################   Route 53  #################################### " >> tmp_r53_tpl.txt
echo "############################## ########### #################################### " >> tmp_r53_tpl.txt


while read line; do

  sed "s/replace_me_node/$line/g" ./templates/route53.tpl > tmp_r53_1.txt
  sed "s/replace_me_var_node_count/$node_count/g" tmp_r53_1.txt > tmp_r53_2.txt
  sed "s/replace_me_env/$env/g" tmp_r53_2.txt >> tmp_r53_tpl.txt
  ((node_count++))
  rm -rf tmp_r53_1.txt
  rm -rf tmp_r53_2.txt
done < $filename

cat tmp_r53_tpl.txt >> tmp_nifi_tf.txt

##Prepare final r53 entry for nifi_yml

no_of_nodes=$(< "node_list.txt" wc -l)
sed "s/replace_me_env/$env/g" ./templates/final_r53.tpl >> tmp_fr53.txt

node_count=1;
f_url='    records = [ ';
#cat ./templates/final_r53.tpl > tmp_fr53.txt

while read line; do
  if [ $no_of_nodes -eq  1 ] ; then
    #echo '$no_of_nodes -eq  1 '
    f_url+='"${module.nifi.private_ip[0]}"'
    f_url+=' ]'
  elif [ $node_count -eq 1 ] ; then
    #echo '$node_count -eq  1 '
    #echo "$f_url"
    #f_url+='$'
    f_url+='"${module.nifi.private_ip[0]}"'
    #echo "$f_url"
  elif [ $node_count -eq  $no_of_nodes ]; then
    #echo '$node_count -eq  $no_of_nodes'
    #echo "$f_url"
    value=$node_count
    ((value--))
    f_url+=","
    #f_url+='$'
    f_url+='"${module.nifi.private_ip['
    f_url+=$value
    f_url+=']}" ] '
#    f_url+=' ]'
    #echo "$f_url"
  else
    {
    #echo 'else'
      value=$node_count
      ((value--))
      f_url+=","
      #f_url+='$'
      f_url+='"${module.nifi.private_ip['
      f_url+=$value
      f_url+=']}" '
    }
  fi
((node_count++))
done < $filename

echo $f_url >> tmp_fr53.txt

echo "}" >> tmp_fr53.txt

cat tmp_fr53.txt >> tmp_nifi_tf.txt

mv tmp_nifi_tf.txt ../nifi.tf

## Cleanup
rm -rf tmp*
