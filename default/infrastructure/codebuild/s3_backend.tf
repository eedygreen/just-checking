terraform {
  backend "s3" {
    dynamodb_table = var.dynamodb_table
    key            = "default/codebuild/terraform.tfstate"
    role_arn       = var.role_arn
  }
}
