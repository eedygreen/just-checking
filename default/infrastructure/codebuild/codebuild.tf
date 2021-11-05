module "codebuild-default" {
  application_name                       = var.application_name
  aws_region                             = var.aws_region
  build_template_base_image              = var.environment == "prod" ? "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.application_name}/codebuild-base:${var.image_version}" : "115072226992.dkr.ecr.${var.aws_region}.amazonaws.com/${var.application_name}/codebuild-base:${var.image_version}"
  build_template_codebuild_build_timeout = 30
  build_template_codebuild_name          = "default"
  build_template_codebuild_description   = "Builder project for default"
  build_template_github_url              = "https://github.com/bitsoex/default.git"
  build_template_github_repository       = "default"
  build_template_image_repo_name         = "bitso/default"
  eks_cluster_name                       = "bitsocluster${var.environment}.bitsoops.com"
  environment                            = var.environment
  environment_variables                  = {}
  github_oauth_token                     = var.github_oauth_token

  secrets_manager = concat([
    {
      secret_name  = data.aws_secretsmanager_secret.github_read_token.name
      secret_arn   = data.aws_secretsmanager_secret.github_read_token.arn
      env_variable = "GITHUB_READ_TOKEN"
    },
    {
      secret_name  = data.aws_secretsmanager_secret.slack_webhook_url.name
      secret_arn   = data.aws_secretsmanager_secret.slack_webhook_url.arn
      env_variable = "SLACK_WEBHOOK_URL"
    }
    ],
    # Add BORT_API_KEY only for non prod environments
    var.environment == "prod" ? [] :
    [
      {
        secret_name  = data.aws_secretsmanager_secret.bort_api_key.name
        secret_arn   = data.aws_secretsmanager_secret.bort_api_key.arn
        env_variable = "BORT_API_KEY"
      }
    ]
  )

  subnet_arns            = data.aws_subnet.private_subnet[*].arn
  subnet_ids             = data.aws_subnet.private_subnet[*].id
  source_git_clone_depth = 5
  source                 = "github.com/bitsoex/bitso-devops/terraform/modules/build_template"
  vpc_id                 = data.aws_vpc.vpc.id
}
