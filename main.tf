resource "random_password" "random_string" {
  count            = var.create_secret ? 1 : 0
  length           = var.length
  lower            = var.use_lower
  number           = var.use_number
  min_lower        = var.min_lower
  min_numeric      = var.min_numeric
  min_special      = var.min_special
  min_upper        = var.min_upper
  override_special = var.override_special == "" ? null : var.override_special
  special          = var.use_special
  upper            = var.use_upper

  keepers = {
    pass_version = var.pass_version
  }
}

resource "aws_secretsmanager_secret" "secret" {
  count                   = var.create_secret ? 1 : 0
  name                    = var.name == "" ? null : var.name
  name_prefix             = var.name == "" ? var.name_prefix : null
  description             = var.description
  kms_key_id              = var.kms_key_id
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "secret_val" {
  count         = var.create_secret ? 1 : 0
  secret_id     = aws_secretsmanager_secret.secret[0].id
  secret_string =  random_password.random_string[0].result
}


resource "aws_cloudwatch_log_metric_filter" "secret_access" {
  count          = var.enable_secret_access_notification ? 1 : 0
  name           = "${var.name_prefix}secret-access"
  log_group_name = var.cloudtrail_log_group
  pattern        = "{ $.eventName = \"GetSecretValue\" && $.requestParameters.secretId = \"${aws_secretsmanager_secret.secret[0].arn}\" }"

  metric_transformation {
    default_value = 0
    name          = "${local.name_prefix}SecretAccessed"
    namespace     = var.secret_access_metric_namespace
    value         = 1
  }
}

locals {
  name_prefix = var.name == "" ? var.name_prefix : var.name
}


resource "aws_cloudwatch_metric_alarm" "unauthorized_cloudtrail_calls" {
  count               = var.enable_secret_access_notification ? 1 : 0
  alarm_actions       = [var.secret_access_notification_arn]
  alarm_name          = "${local.name_prefix}secret-access"
  alarm_description   = "Monitor usage of secret: ${aws_secretsmanager_secret.secret[0].id}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "${local.name_prefix}SecretAccessed"
  namespace           = var.secret_access_metric_namespace
  period              = 60
  statistic           = "Sum"
  tags                = var.tags
  threshold           = 1
}


# create lambda function for secrets rotation
resource "aws_lambda_function" "redshift_secret" {
  filename      = "${path.module}/lambdafunction.zip"
  function_name = var.lambda_function_name
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "index.test"

  source_code_hash = filebase64sha256("${path.module}/lambdafunction.zip")

  runtime = "python3.7"

}



resource "aws_secretsmanager_secret_rotation" "redshift_secret_rotation" {
  count               = var.enable_secrets_rotation ? 1 : 0
  secret_id           = aws_secretsmanager_secret.secret[0].id
  rotation_lambda_arn = aws_lambda_function.redshift_secret.arn

  rotation_rules {
    automatically_after_days = var.number_of_days_for_rotatating_secrets
  }
  depends_on = [
    aws_iam_role_policy.secrets,
    aws_lambda_permission.allow_secretmanager
  ]
}
