#!/bin/sh
filename='private_buckets.txt'

#cp ../providers.tf ./providers.tf
#cp ../variables.tf  ./variables.tf
#cp ../terraform.tfvars ../terraform.ftvars

rm -rf ./s3.tf

while read line; do
	cp ./s3_private.tpl ./$line.tf-tmp	
	sed "s/replace_me_name/$line/g" $line.tf-tmp >> s3.tf
	rm -rf $line.tf-tmp
done < $filename

filename='public_buckets.txt'

while read line; do
        cp ./s3_public.tpl ./$line.tf-tmp
        sed "s/replace_me_name/$line/g" $line.tf-tmp >> s3.tf
        rm -rf $line.tf-tmp
done < $filename

mv ./s3.tf ../s3.tf
