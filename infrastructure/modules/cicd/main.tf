resource "aws_s3_bucket" "amibuild_codepipeline_bucket" {
  bucket        = "eniolaamibuildartifactcodepipeline"
  force_destroy = true
}

resource "aws_iam_role" "codepipeline_role" {
  name = "amibuild_codepipeline_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "amibuild_codepipeline_policy"
  role = aws_iam_role.codepipeline_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.amibuild_codepipeline_bucket.arn}",
        "${aws_s3_bucket.amibuild_codepipeline_bucket.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_codepipeline" "amibuild_codepipeline" {
  name     = "pack-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.amibuild_codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["amibuild_artifacts"]

      configuration = {
        ConnectionArn        = aws_codestarconnections_connection.github_connection.arn
        FullRepositoryId     = var.repository
        BranchName           = "main"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["amibuild_artifacts"]
      output_artifacts = ["amibuid_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.amibuild_codebuild.name
      }
    }
  }
}

resource "aws_codestarconnections_connection" "github_connection" {
#  provider_type     = "GitHub"
  name              = "amibuild_github_connection"
  host_arn          = var.github_host_arn
#  connection_status = "PENDING"
  tags = {
    Name = "GitHub Connection"
  }
}

resource "aws_codepipeline_webhook" "amibuild_cp_wh" {
  name            = "amibuild_cp_webhook"
  authentication  = "GITHUB_HMAC"
  target_action   = "Source"
  target_pipeline = aws_codepipeline.amibuild_codepipeline.name

  authentication_configuration {
    secret_token = var.github_Oauthtoken
  }

  filter {
    json_path    = "$.ref"
    match_equals = "refs/heads/{Branch}"
  }
}

# Wiring the codepipeline webhook into a github repo
#resource "github_repository_webhook" "github_webhook" {
#  repository = data.github_repository.repo.name

#  configuration {
#    url          = aws_codepipeline_webhook.amibuild_cp_wh.url
#    content_type = "json"
#    insecure_ssl = false
#    secret       = var.github_token
#  }

#  events = ["push"]
#}

### code build

resource "aws_s3_bucket" "codebuild_log" {
  bucket        = "eniolaamibuildcodebuildlog"
  force_destroy = true
}

resource "aws_iam_role" "codebuild_role" {
  name = "amibuild_codebuild_log"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuile_policy" {
  role = aws_iam_role.codebuild_role.name

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.codebuild_log.arn}",
        "${aws_s3_bucket.codebuild_log.arn}/*",
        "${aws_s3_bucket.amibuild_codepipeline_bucket.arn}",
        "${aws_s3_bucket.amibuild_codepipeline_bucket.arn}/*"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "poweruser_access" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_codebuild_project" "amibuild_codebuild" {
  name          = "amibuild_codebuild"
  description   = "AMI Build Codebuild pipeline"
  build_timeout = "15"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type     = "S3"
    location = aws_s3_bucket.codebuild_log.bucket
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:1.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AMIID_SSMPS"
      value = var.ami_id_ssmps
    }

    environment_variable {
      name  = "SNS_ARN"
      value = aws_sns_topic.amibuild_notification.arn
    }

    environment_variable {
      name  = "BASE_AMI"
      value = var.base_ami_id
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "amibuild_log-group"
      stream_name = "amibuild_log-stream"
    }

    s3_logs {
      status   = "ENABLED"
      location = "${aws_s3_bucket.codebuild_log.id}/build-log"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "./infrastructure/temp/buildspec.yml"
  }

  # source_version = "master"
}

resource "aws_sns_topic" "amibuild_notification" {
  name = "amibuild_notification"

  provisioner "local-exec" {
    command = "sh ${path.module}/scripts/sns_subscription.sh"

    environment = {
      sns_arn     = self.arn
      sns_emails  = var.emailids
      region      = var.region
      aws_profile = var.aws_profile
    }
  }
}
