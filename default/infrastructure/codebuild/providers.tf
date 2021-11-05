provider "aws" {
  default_tags {
    tags = {
      environment = var.environment
      owner       = "bitso"
      project     = "codebuild"
      service     = "default"
    }
  }
  profile = var.aws_profile
  region  = var.aws_region
  assume_role {
    role_arn     = var.role_arn
    session_name = "default-infra-session"
  }
}

provider "github" {
  token = var.github_oauth_token
  owner = "bitsoex"
}
