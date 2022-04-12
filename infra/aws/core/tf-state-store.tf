locals {
   aws_s3_tf_state_bucket = "${local.env_name_lower}-tf-state-${random_string.ENV_SUFFIX.result}"
}

resource "aws_s3_bucket" "aws_s3_tf_state" {
  bucket = local.aws_s3_tf_state_bucket
  tags = {
    Name = "${var.ENV_NAME} Terraform State Bucket"
    Environment = "${var.ENV_NAME}"
  }
  tags_all = {
    Environment = "${var.ENV_NAME}"
  }
}
resource "aws_s3_bucket_acl" "aws_s3_tf_state" {
  bucket = aws_s3_bucket.aws_s3_tf_state.id
  acl    = "private"
}
resource "aws_s3_bucket_versioning" "aws_s3_tf_state" {
  bucket = aws_s3_bucket.aws_s3_tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "aws_s3_tf_state" {
  bucket = aws_s3_bucket.aws_s3_tf_state.bucket
  rule {
    bucket_key_enabled = true
  }
}
resource "aws_s3_bucket_public_access_block" "aws_s3_tf_state" {
  bucket = aws_s3_bucket.aws_s3_tf_state.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}
output "aws_s3_tf_state_id" {
  value = aws_s3_bucket.aws_s3_tf_state.id
}
