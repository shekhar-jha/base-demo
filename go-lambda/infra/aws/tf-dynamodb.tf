locals {
  go_dynamodb_table_name = "${local.env_name_lower}_Messages"# "${local.env_name_lower}_go_db_${local.env_suffix}"
}

resource "aws_dynamodb_table" "go-dynamodb" {
  name           = local.go_dynamodb_table_name
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "Name"
  #  range_key      = "GameTitle"

  attribute {
    name = "Name"
    type = "S"
  }

  ttl {
    attribute_name = "TimeToExist"
    enabled        = false
  }
  tags = {
    Name        = local.go_dynamodb_table_name
    Environment = var.ENV_NAME
  }
  # Needed to avoid triggering changes during tf updates
  lifecycle {
    ignore_changes = [read_capacity, write_capacity, ttl]
  }
}

data "aws_iam_policy_document" "go-dynamodb-access-policy" {
  statement {
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:ConditionCheckItem",
      "dynamodb:GetItem",
      "dynamodb:ListTagsOfResource",
      "dynamodb:PartiQLDelete",
      "dynamodb:PartiQLInsert",
      "dynamodb:PartiQLSelect",
      "dynamodb:PartiQLUpdate",
      "dynamodb:PutItem",
      "dynamodb:Query",
      "dynamodb:UpdateItem",
      # May need to be checked
      "dynamodb:DeleteItem",
      "dynamodb:Scan",
    ]
    resources = [aws_dynamodb_table.go-dynamodb.arn]
    effect    = "Allow"
  }
}

resource "aws_iam_role_policy" "go-dynamodb-role-access" {
  name   = "${local.env_name_lower}_dynamodb_access"
  role   = aws_iam_role.go_function.id
  policy = data.aws_iam_policy_document.go-dynamodb-access-policy.json
}

