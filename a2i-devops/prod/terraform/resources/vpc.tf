################################################################################
### VPC default security group
################################################################################

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = module.vpc.vpc_id
}

################################################################################
### VPC
################################################################################

module "vpc" {
  source = "../modules/terraform-aws-vpc"
  enable_dns_hostnames = true
  enable_dns_support   = true

  one_nat_gateway_per_az = false
  enable_nat_gateway = true
  single_nat_gateway = true
  name = "${var.platform}-${local.environment}"

  cidr = local.variables[terraform.workspace].vpc_cidr

  azs               = ["${var.aws_region}a", "${var.aws_region}b"]
  public_subnets    = [cidrsubnet(local.variables[terraform.workspace].vpc_cidr, 8, 0), cidrsubnet(local.variables[terraform.workspace].vpc_cidr, 8, 1)]
  database_subnets  = [cidrsubnet(local.variables[terraform.workspace].vpc_cidr, 7, 1), cidrsubnet(local.variables[terraform.workspace].vpc_cidr, 7, 2)]
  private_subnets   = [cidrsubnet(local.variables[terraform.workspace].vpc_cidr, 7, 3), cidrsubnet(local.variables[terraform.workspace].vpc_cidr, 7, 4)]

  public_subnet_tags = {
    Name        =  "${var.platform}-public-${local.environment}"
  }

  private_subnet_tags = {
    Name        =  "${var.platform}-private-app-${local.environment}"
  }

  database_subnet_tags = {
    Name        =  "${var.platform}-private-db-${local.environment}"
  }

  database_subnet_group_tags = {
    Name        = "${var.platform}-db-subnet-group-${local.environment}"
  }

  private_route_table_tags = {
    Name        = "${var.platform}-private-rt-${local.environment}"
  }

  public_route_table_tags = {
    Name        = "${var.platform}-public-rt-${local.environment}"
  }

  database_route_table_tags = {
    Name = "${var.platform}-dbrt-${local.environment}"
  }

  nat_gateway_tags = {
    Name = "${var.platform}-ngw-${local.environment}"
  }

  igw_tags = {
    Name = "${var.platform}-igw-${local.environment}"
  }

  nat_eip_tags = {
    Name = "${var.platform}-nat-eip-${local.environment}"
  }

  enable_vpn_gateway = false

  tags = {
    Owner       = "terraform"
    Environment = "${local.environment}"
    Name        = "${var.platform}-${local.environment}"
  }
}


################################################################################
### Routes for transit gateways
################################################################################

### CloudForce
resource "aws_route" "route_for_cf_for_public" {
  route_table_id            = module.vpc.public_route_table_ids[0]
  destination_cidr_block    = "172.31.0.0/16"
  transit_gateway_id        = local.variables[terraform.workspace].transit_gateway_id
  depends_on                = [module.vpc]
}

resource "aws_route" "route_for_cf_for_private" {
  route_table_id            = module.vpc.private_route_table_ids[0]
  destination_cidr_block    = "172.31.0.0/16"
  transit_gateway_id        = local.variables[terraform.workspace].transit_gateway_id
  depends_on                = [module.vpc]
}

### DataCenter
resource "aws_route" "route_for_dc_for_public" {
  route_table_id            = module.vpc.public_route_table_ids[0]
  destination_cidr_block    = "172.27.0.0/16"
  transit_gateway_id        = local.variables[terraform.workspace].transit_gateway_id
  depends_on                = [module.vpc]
}

resource "aws_route" "route_for_dc_for_private" {
  route_table_id            = module.vpc.private_route_table_ids[0]
  destination_cidr_block    = "172.27.0.0/16"
  transit_gateway_id        = local.variables[terraform.workspace].transit_gateway_id
  depends_on                = [module.vpc]
}

### Hyke Prod
resource "aws_route" "route_for_hyke-prod_for_public" {
  route_table_id            = module.vpc.public_route_table_ids[0]
  destination_cidr_block    = "10.80.0.0/16"
  transit_gateway_id        = local.variables[terraform.workspace].transit_gateway_id
  depends_on                = [module.vpc]
}

resource "aws_route" "route_for_hyke-prod_for_private" {
  route_table_id            = module.vpc.private_route_table_ids[0]
  destination_cidr_block    = "10.80.0.0/16"
  transit_gateway_id        = local.variables[terraform.workspace].transit_gateway_id
  depends_on                = [module.vpc]
}

### Hyke Stage
resource "aws_route" "route_for_hyke-stage_for_public" {
  route_table_id            = module.vpc.public_route_table_ids[0]
  destination_cidr_block    = "10.81.0.0/16"
  transit_gateway_id        = local.variables[terraform.workspace].transit_gateway_id
  depends_on                = [module.vpc]
}

resource "aws_route" "route_for_hyke-stage_for_private" {
  route_table_id            = module.vpc.private_route_table_ids[0]
  destination_cidr_block    = "10.81.0.0/16"
  transit_gateway_id        = local.variables[terraform.workspace].transit_gateway_id
  depends_on                = [module.vpc]
}

### A2i Prod Routes
resource "aws_route" "route_for_existing_prod_for_public" {
  route_table_id            = module.vpc.public_route_table_ids[0]
  destination_cidr_block    = "10.10.0.0/16"
  transit_gateway_id        = local.variables[terraform.workspace].transit_gateway_id
  depends_on                = [module.vpc]
}

resource "aws_route" "route_for_existing_prod_for_private" {
  route_table_id            = module.vpc.private_route_table_ids[0]
  destination_cidr_block    = "10.10.0.0/16"
  transit_gateway_id        = local.variables[terraform.workspace].transit_gateway_id
  depends_on                = [module.vpc]
}

### A2i stage
resource "aws_route" "route_for_a2i-stage_for_public" {
  route_table_id            = module.vpc.public_route_table_ids[0]
  destination_cidr_block    = "10.12.0.0/16"
  transit_gateway_id        = local.variables[terraform.workspace].transit_gateway_id
  depends_on                = [module.vpc]
}

resource "aws_route" "route_for_a2i-stage_for_private" {
  route_table_id            = module.vpc.private_route_table_ids[0]
  destination_cidr_block    = "10.12.0.0/16"
  transit_gateway_id        = local.variables[terraform.workspace].transit_gateway_id
  depends_on                = [module.vpc]
}

### Hyke Dev
resource "aws_route" "route_for_hyke-dev_for_public" {
  route_table_id            = module.vpc.public_route_table_ids[0]
  destination_cidr_block    = "10.50.0.0/16"
  transit_gateway_id        = local.variables[terraform.workspace].transit_gateway_id
  depends_on                = [module.vpc]
}

resource "aws_route" "route_for_hyke-dev_for_private" {
  route_table_id            = module.vpc.private_route_table_ids[0]
  destination_cidr_block    = "10.50.0.0/16"
  transit_gateway_id        = local.variables[terraform.workspace].transit_gateway_id
  depends_on                = [module.vpc]
}

### Hyke QA
resource "aws_route" "route_for_hyke-qa_for_public" {
  route_table_id            = module.vpc.public_route_table_ids[0]
  destination_cidr_block    = "10.60.0.0/16"
  transit_gateway_id        = local.variables[terraform.workspace].transit_gateway_id
  depends_on                = [module.vpc]
}

resource "aws_route" "route_for_hyke-qa_for_private" {
  route_table_id            = module.vpc.private_route_table_ids[0]
  destination_cidr_block    = "10.60.0.0/16"
  transit_gateway_id        = local.variables[terraform.workspace].transit_gateway_id
  depends_on                = [module.vpc]
}

### Hyke APIs
resource "aws_route" "route_for_hyke-APIs_for_public" {
  route_table_id            = module.vpc.public_route_table_ids[0]
  destination_cidr_block    = "10.70.0.0/16"
  transit_gateway_id        = local.variables[terraform.workspace].transit_gateway_id
  depends_on                = [module.vpc]
}

resource "aws_route" "route_for_hyke-APIs_for_private" {
  route_table_id            = module.vpc.private_route_table_ids[0]
  destination_cidr_block    = "10.70.0.0/16"
  transit_gateway_id        = local.variables[terraform.workspace].transit_gateway_id
  depends_on                = [module.vpc]
}