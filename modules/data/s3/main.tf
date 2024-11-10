resource "aws_s3_bucket" "private_bucket" {
    bucket = "auther-${var.deployment_env}"

  tags = {
    Name        = "auther-${var.deployment_env}"
    Environment = var.deployment_env
  }
}

resource "aws_s3_bucket_object" "apps_dir" {
  bucket = aws_s3_bucket.private_bucket.id
  acl    = "private"
  key    = "applications/"
  source = "/dev/null"
}
