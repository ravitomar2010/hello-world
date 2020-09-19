# Terraform

Repo conatins terraform modules which creates resources on AWS. 

Supported AWS Resources:
 - VPC

## Terraform versions
```
Terraform v0.12.2  
+ provider.aws v2.15.0
```

Release Notes: https://github.com/hashicorp/terraform/releases/tag/v0.12.2 


## Installation Steps 

Terraform is distributed as a single binary. Install Terraform by unzipping it and moving it to a directory included in your system's PATH .

macOS: https://releases.hashicorp.com/terraform/0.12.2/terraform_0.12.2_darwin_amd64.zip

Linux 64-bit: https://releases.hashicorp.com/terraform/0.12.2/terraform_0.12.2_linux_amd64.zip 

## Example Setup for an entity.

- How to setup admin-tools ?
    - Define AWS config in aws.tf file inside admin-tools.
    - Create resources using module. 
    - Refer module README.md for respective input and output

```
cd devops/terraform/<admin-tools>
terraform init
terraform plan 
terraform apply
```
