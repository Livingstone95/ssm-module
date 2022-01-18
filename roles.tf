resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "secrets" {
  count = var.create_secret ? 1 : 0
  name = "redshift_secrets"
  role = aws_iam_role.iam_for_lambda.id

  policy = jsonencode(
      {
        "Version": "2012-10-17",
        "Statement" : [
          {
          "Action": [
              "secretsmanager:DescribeSecret",
              "secretsmanager:GetSecretValue",
              "secretsmanager:PutSecretValue",
              "secretsmanager:UpdateSecretVersionStage"
          ],
          "Resource": "${aws_secretsmanager_secret.secret[count.index].arn}:*",
          "Effect": "Allow"
          "Condition": {
              "StringEquals": {
                  "secretsmanager:resource/AllowRotationLambdaArn": "${aws_lambda_function.redshift_secret.arn}"
              }
          }
          }
      ]
    }
  )
}

resource "aws_iam_role_policy" "lambda_logging" {
  name = "lamda_logging"
  role = aws_iam_role.iam_for_lambda.id

  policy = jsonencode(
    {
      "Version": "2012-10-17",
      "Statement": [
          {
                "Effect": "Allow",
                "Action": [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents"
                ],
                "Resource": "*"
            },

            {
                "Effect": "Allow",
                "Action": [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents",
                    "ec2:CreateNetworkInterface",
                    "ec2:DescribeNetworkInterfaces",
                    "ec2:DeleteNetworkInterface",
                    "ec2:AssignPrivateIpAddresses",
                    "ec2:UnassignPrivateIpAddresses"
                ],
                "Resource": "*"
            },
            
            {
                "Action": [
                    "ec2:CreateNetworkInterface",
                    "ec2:DeleteNetworkInterface",
                    "ec2:DescribeNetworkInterfaces",
                    "ec2:DetachNetworkInterface"
                ],
                "Resource": "*",
                "Effect": "Allow"
            },

            {
                "Action": [
                    "secretsmanager:GetRandomPassword"
                ],
                "Resource": "*",
                "Effect": "Allow"
            }

        #     {
        #         "Action": [
        #             "kms:Decrypt",
        #             "kms:DescribeKey",
        #             "kms:GenerateDataKey"
        #         ],
        #         "Resource": "${aws_kms_key.secrets.arn}",
        #         "Effect": "Allow"
        # }   
      ]
    })
}

resource "aws_lambda_permission" "allow_secretmanager" {
  statement_id  = "AllowExecutionFromSecretManager"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.redshift_secret.function_name
  principal     = "secretsmanager.amazonaws.com"
}