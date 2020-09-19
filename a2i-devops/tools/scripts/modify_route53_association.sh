#!/bin/bash

stage_zone_id="Z02262471JWHMXFG9ICGM"
infra_zone_id="Z022622321HG7G07ECKFC"
prod_zone_id="Z09306541C50VTHUE5A6Q"

stage_vpc="vpc-06cfe54f0455d50e9"
prod_vpc="vpc-08556c49da6c6f3c1"

echo "Updating association for prod account for a2i.stage zone"

aws route53 associate-vpc-with-hosted-zone --hosted-zone-id $stage_zone_id --vpc "VPCRegion=eu-west-1,VPCId=$prod_vpc" --profile prod

echo "Updating association authorization for prod account for a2i.stage zone"

aws route53 create-vpc-association-authorization --hosted-zone-id $stage_zone_id --vpc "VPCRegion=eu-west-1,VPCId=$prod_vpc" --profile stage


echo "Updating association for prod account for a2i.infra zone"

aws route53 associate-vpc-with-hosted-zone --hosted-zone-id $infra_zone_id --vpc "VPCRegion=eu-west-1,VPCId=$prod_vpc" --profile prod

echo "Updating association authorization for prod account for a2i.infra zone"

aws route53 create-vpc-association-authorization --hosted-zone-id $infra_zone_id --vpc "VPCRegion=eu-west-1,VPCId=$prod_vpc" --profile stage


echo "Updating association for stage account for a2i.prod zone"

aws route53 associate-vpc-with-hosted-zone --hosted-zone-id $prod_zone_id --vpc "VPCRegion=eu-west-1,VPCId=$stage_vpc" --profile stage

echo "Updating association authorization for prod account for a2i.prod zone"

aws route53 create-vpc-association-authorization --hosted-zone-id $prod_zone_id --vpc "VPCRegion=eu-west-1,VPCId=$stage_vpc" --profile prod
