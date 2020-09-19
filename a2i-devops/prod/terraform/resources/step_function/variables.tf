## Environment and Provider Inputs
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

variable "platform" {
  description = "Platform for which infrastructure is being developed"
}

variable "aws_region" {
  description = "Region where resources would be created"
}

variable "aws_sfn_role_arn" {
  description = "Role ARN for step function to execute"
}
