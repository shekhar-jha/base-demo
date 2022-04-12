data "local_sensitive_file" "aws_tf_crypt" {
  filename = "${path.module}/${local.env_name_lower}-tf-gpg-pub.pub"
}

