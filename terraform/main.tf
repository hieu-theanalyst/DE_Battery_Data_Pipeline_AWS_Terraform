data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  count   = var.use_default_vpc ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = var.use_default_vpc ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
}

locals {
  vpc_id     = var.use_default_vpc ? data.aws_vpc.default[0].id : var.vpc_id
  subnet_ids = var.use_default_vpc ? data.aws_subnets.default[0].ids : var.subnet_ids

  name_prefix = "${var.project_name}-${var.environment}"
}
