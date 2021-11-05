data "aws_caller_identity" "current" {}

data "aws_secretsmanager_secret" "github_read_token" {
  name = "/${var.application_name}/${var.environment}/codebuild/github-read-token"
}

data "aws_secretsmanager_secret" "slack_webhook_url" {
  name = "/${var.application_name}/${var.environment}/codebuild/slack-webhook-url"
}

data "aws_secretsmanager_secret" "bort_api_key" {
  name = "/${var.application_name}/${var.environment}/codebuild/bort-api-key"
}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = ["${local.vpc_prefix[var.environment]}${local.suffix[var.environment]}"]
  }
}

data "aws_subnet" "private_subnet" {
  count  = length(local.zones)
  vpc_id = data.aws_vpc.vpc.id
  tags = {
    Name = "${local.subnet_prefix[var.environment]}${var.aws_region}${local.zones[count.index]}.${local.suffix[var.environment]}"
  }
}
