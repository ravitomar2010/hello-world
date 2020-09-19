module "redis" {
  source  = "../modules/terraform-aws-elasticache"

  env             = local.environment
  name            = "${var.platform}-redis-${local.environment}"
  redis_clusters  = local.variables[terraform.workspace].elasticache.redis.nodes
  redis_failover  = "true"
  auth_token      = local.variables[terraform.workspace].elasticache.redis.auth_token
  redis_node_type = local.variables[terraform.workspace].elasticache.redis.node_type
  subnets         = module.vpc.database_subnets
  vpc_id          = module.vpc.vpc_id
  allowed_cidr    = ["${local.variables[terraform.workspace].vpc_cidr}"]
  redis_shards    = local.variables[terraform.workspace].elasticache.redis.redis_shards

  redis_parameters = [{
    name  = "databases"
    value = "32"
  },
  {
    name  = "notify-keyspace-events"
    value = "EKA"
  },
  {
    name  = "cluster-enabled"
    value = "yes"
  }]

  tags = {
    name  = "Platform"
    value = "${var.platform}"
  }
}