resource "aws_dynamodb_table" "applications" {
  name           = "auther_${var.deployment_env}_applications"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name        = "auther_${var.deployment_env}_applications"
    Environment = var.deployment_env
  }
}

# TODO: Add Auto Scaling as required