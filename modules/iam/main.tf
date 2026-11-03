# Roles for ECS, CodeDeploy and GitHub Actions. The GitHub OIDC provider is the Landing Zone's
# (github_oidc_provider_arn): it is referenced here, never created. The original project's
# wildcard "*:*" admin-style role is replaced by a deploy-only role.

locals {
  ecr_repo_arn = "arn:${var.partition}:ecr:${var.region}:${var.account_id}:repository/${var.ecr_repository_name}"
  service_arn  = "arn:${var.partition}:ecs:${var.region}:${var.account_id}:service/${var.cluster_name}/${var.service_name}"
  cd_app_arn   = "arn:${var.partition}:codedeploy:${var.region}:${var.account_id}:application:${var.codedeploy_app_name}"
  cd_dg_arn    = "arn:${var.partition}:codedeploy:${var.region}:${var.account_id}:deploymentgroup:${var.codedeploy_app_name}/${var.codedeploy_group_name}"
  cd_cfg_arn   = "arn:${var.partition}:codedeploy:${var.region}:${var.account_id}:deploymentconfig:*"
}

# ---- ECS task assume-role (shared by execution and task roles)
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

# ---- Execution role: pulls the image from the Landing Zone ECR and writes logs
resource "aws_iam_role" "execution" {
  name               = "${var.name_prefix}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:${var.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---- Task role: least privilege on this workload's table (and queue)
resource "aws_iam_role" "task" {
  name               = "${var.name_prefix}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

data "aws_iam_policy_document" "task" {
  statement {
    sid       = "UrlTable"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query"]
    resources = [var.dynamodb_table_arn]
  }

  dynamic "statement" {
    for_each = var.dynamodb_kms_key_arn != null ? [1] : []
    content {
      sid       = "TableCmk"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
      resources = [var.dynamodb_kms_key_arn]
    }
  }

  dynamic "statement" {
    for_each = var.sqs_queue_arn != null ? [1] : []
    content {
      sid       = "ClickEvents"
      actions   = ["sqs:SendMessage"]
      resources = [var.sqs_queue_arn]
    }
  }
}

resource "aws_iam_role_policy" "task" {
  name   = "workload-access"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task.json
}

# ---- CodeDeploy service role
data "aws_iam_policy_document" "codedeploy_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codedeploy" {
  name               = "${var.name_prefix}-codedeploy"
  assume_role_policy = data.aws_iam_policy_document.codedeploy_assume.json
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:${var.partition}:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# ---- GitHub Actions deploy role (trusts the Landing Zone OIDC provider)
data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.github_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:environment:${var.environment}"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name                 = "${var.name_prefix}-github-deploy"
  assume_role_policy   = data.aws_iam_policy_document.github_assume.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "github_deploy" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability", "ecr:CompleteLayerUpload", "ecr:InitiateLayerUpload",
      "ecr:PutImage", "ecr:UploadLayerPart", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer",
    ]
    resources = [local.ecr_repo_arn]
  }

  statement {
    sid       = "TaskDefinitions"
    actions   = ["ecs:RegisterTaskDefinition", "ecs:DescribeTaskDefinition"]
    resources = ["*"] # ECS task definition actions do not support resource-level scoping
  }

  statement {
    sid       = "ServiceRead"
    actions   = ["ecs:DescribeServices"]
    resources = [local.service_arn]
  }

  statement {
    sid       = "CodeDeployDeploy"
    actions   = ["codedeploy:CreateDeployment", "codedeploy:GetDeployment", "codedeploy:GetApplicationRevision", "codedeploy:RegisterApplicationRevision"]
    resources = [local.cd_app_arn, local.cd_dg_arn]
  }

  statement {
    sid       = "CodeDeployConfig"
    actions   = ["codedeploy:GetDeploymentConfig"]
    resources = [local.cd_cfg_arn]
  }

  statement {
    sid       = "PassOnlyWorkloadRoles"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.execution.arn, aws_iam_role.task.arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "deploy-only"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}
