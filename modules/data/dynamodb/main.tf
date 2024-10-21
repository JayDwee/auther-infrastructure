resource "aws_dynamodb_table" "authorization_server" {
  name           = "auther_${var.deployment_env}_authorization_server"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "id"

  tags = {
    Name        = "auther_${var.deployment_env}_authorization_server"
    Environment = var.deployment_env
  }
}

# TODO: Add Auto Scaling as required