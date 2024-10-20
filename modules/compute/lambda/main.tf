data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "auther-${var.deployment_env}-lambdaexecute-iam-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "s3_role_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

data "aws_iam_policy_document" "cloudwatch_readwrite" {
  statement {
    effect = "Allow"
    actions = ["logs:CreateLogGroup",]
    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"]
  }

  statement {
    effect = "Allow"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents",]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:auther-${var.deployment_env}-lambda-execution"
    ]
  }
}

resource "aws_iam_policy" "cloudwatch_readwrite" {
  name   = "auther-${var.deployment_env}-cloudwatch-readwrite-iam-policy"
  policy = data.aws_iam_policy_document.cloudwatch_readwrite.json
}


resource "aws_iam_role_policy_attachment" "execution_role_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.cloudwatch_readwrite.arn
}

resource "aws_lambda_function" "lambda_function" {
  function_name = "auther-${var.deployment_env}-lambda-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "main"

  runtime = "provided.al2023"

  environment {
    variables = {
      API_GATEWAY_BASE_PATH = "/default"
    }
  }
}