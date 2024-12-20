data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_api_gateway_rest_api" "api" {
  name = "auther-${var.deployment_env}-api"
}

resource "aws_api_gateway_resource" "well_known" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = ".well-known"
}

resource "aws_api_gateway_resource" "well_known_object" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.well_known.id
  path_part   = "{object}"
}

resource "aws_api_gateway_resource" "default" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "get_s3_well_known" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.well_known_object.id
  authorization = "NONE"
  http_method   = "GET"

  request_parameters = {
    "method.request.path.object" = true
  }
}

resource "aws_api_gateway_method" "get_s3_default" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.default.id
  authorization = "NONE"
  http_method   = "GET"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_method_response" "s3_response_200" {
  for_each = toset([aws_api_gateway_resource.well_known_object.id, aws_api_gateway_resource.default.id])
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = each.value
  http_method = "GET"
  status_code = "200"
}

resource "aws_api_gateway_method_response" "s3_response_404" {
  for_each = toset([aws_api_gateway_resource.well_known_object.id, aws_api_gateway_resource.default.id])
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = each.value
  http_method = "GET"
  status_code = "404"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "s3access" {
  name               = "auther-${var.deployment_env}-s3access-iam-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  role       = aws_iam_role.s3access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_push_attachment" {
  role       = aws_iam_role.s3access.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_integration" "get_well_known_integration" {
  depends_on = [aws_api_gateway_method.get_s3_well_known]
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.well_known_object.id
  http_method             = "GET"
  integration_http_method = "GET"
  request_parameters = {
    "integration.request.path.app_id" = "context.domainPrefix"
    "integration.request.path.object" = "method.request.path.object"
  }
  type        = "AWS"
  uri         = "arn:aws:apigateway:${data.aws_region.current.name}:s3:path/${var.s3_bucket_name}/applications/{app_id}/.well-known/{object}"
  credentials = aws_iam_role.s3access.arn
}

resource "aws_api_gateway_integration" "get_default_integration" {
  depends_on = [aws_api_gateway_method.get_s3_well_known]
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.default.id
  http_method             = "GET"
  integration_http_method = "GET"
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
  type        = "AWS"
  uri         = "arn:aws:apigateway:${data.aws_region.current.name}:s3:path/${var.s3_bucket_name}/static/{proxy}"
  credentials = aws_iam_role.s3access.arn
}


resource "aws_api_gateway_integration_response" "get_s3_integration_response_200" {
  for_each = toset([aws_api_gateway_resource.well_known_object.id, aws_api_gateway_resource.default.id])
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = each.value
  http_method = "GET"
  status_code = "200"
  depends_on = [
    aws_api_gateway_integration.get_well_known_integration, aws_api_gateway_integration.get_default_integration
  ]

  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_integration_response" "get_s3_integration_response_404" {
  for_each = toset([aws_api_gateway_resource.well_known_object.id, aws_api_gateway_resource.default.id])
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = each.value
  http_method = "GET"
  status_code = "404"
  depends_on = [
    aws_api_gateway_integration.get_well_known_integration, aws_api_gateway_integration.get_default_integration
  ]
  selection_pattern = "404"

  response_templates = {
    "application/json" = "404 Not Found"
  }
}

resource "aws_api_gateway_resource" "oauth2" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "oauth2"
}
resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "api"
}

resource "aws_api_gateway_resource" "lambda_proxy" {
  for_each = {
    for key, value in [aws_api_gateway_resource.oauth2, aws_api_gateway_resource.api] : value.path_part => value.id
  }
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = each.value
  path_part   = "{proxy+}"
}


resource "aws_api_gateway_method" "lambda_proxy" {
  for_each      = aws_api_gateway_resource.lambda_proxy
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = each.value.id
  authorization = "NONE"
  http_method   = "ANY"
}

resource "aws_api_gateway_method_response" "lambda_proxy_response_200" {
  for_each    = aws_api_gateway_resource.lambda_proxy
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = each.value.id
  http_method = "ANY"
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration" "lambda_proxy" {
  depends_on = [aws_api_gateway_method.lambda_proxy]
  for_each                = aws_api_gateway_resource.lambda_proxy
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = each.value.id
  http_method             = "ANY"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arn
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.api.id}/*/ANY/*"
}

resource "aws_api_gateway_deployment" "default" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.well_known.id,
      aws_api_gateway_resource.well_known_object.id,
      aws_api_gateway_resource.default.id,
      aws_api_gateway_method.get_s3_well_known.id,
      aws_api_gateway_method.get_s3_default.id,
      aws_api_gateway_integration.get_well_known_integration.id,
      aws_api_gateway_integration.get_default_integration.id,
      [for val in aws_api_gateway_method_response.s3_response_200 : val.id],
      [for val in aws_api_gateway_method_response.s3_response_404 : val.id],
      [for val in aws_api_gateway_integration_response.get_s3_integration_response_200 : val.id],
      [for val in aws_api_gateway_integration_response.get_s3_integration_response_404 : val.id],
      [for val in aws_api_gateway_resource.lambda_proxy : val.id],
      [for val in aws_api_gateway_method.lambda_proxy : val.id],
      [for val in aws_api_gateway_method_response.lambda_proxy_response_200 : val.id],
      [for val in aws_api_gateway_integration.lambda_proxy : val.id],
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "default" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.default.id
  stage_name    = "default"
}

resource "aws_api_gateway_base_path_mapping" "example" {
  api_id      = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.default.stage_name
  domain_name = var.domain_name # TODO: Create Domain Name Resource
}