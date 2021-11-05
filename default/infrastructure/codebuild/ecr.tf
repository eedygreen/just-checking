resource "aws_ecr_repository" "repository" {
  name                 = "bitso/default"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository_policy" "prod_policy" {
  count      = var.environment == "prod" ? 1 : 0
  repository = aws_ecr_repository.repository.name

  policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "prod access",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::672388688877:root"
        ]
      },
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeImages",
        "ecr:DescribeRepositories",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:ListImages",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ]
    },
    {
      "Sid": "allow tools read",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::115072226992:root"
        ]
      },
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:DescribeImages",
        "ecr:DescribeRepositories",
        "ecr:GetDownloadUrlForLayer",
        "ecr:ListImages"
      ]
    }
  ]
}
EOF
}

resource "aws_ecr_repository_policy" "tools_policy" {
  count      = var.environment == "prod" ? 0 : 1
  repository = aws_ecr_repository.repository.name

  # Allow access to non-prod accounts to read images
  policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "new statement",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::143913848869:root",
          "arn:aws:iam::722970091251:root",
          "arn:aws:iam::745621565518:root"
        ]
      },
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeImages",
        "ecr:DescribeRepositories",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:ListImages",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ]
    }
  ]
}
EOF
}
