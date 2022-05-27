##########################################
# AWS Secret containing Github PAT
##########################################
data "aws_secretsmanager_secret" "github-pat" {
  name = "${var.ENV_NAME}-git-runner"
}

##########################################
# AWS CloudWatch Log group to collect logs
# generated by ECS cluster
##########################################
resource "aws_cloudwatch_log_group" "git_runner" {
  name              = "ecs/${var.ENV_NAME}_git_runner"
  retention_in_days = 1
  tags              = {
    Name        = "${var.ENV_NAME}_git_runner"
    Environment = var.ENV_NAME
  }
}

##########################################
# IAM Role for ECS task
##########################################

resource "aws_iam_role" "git_runner_ecs" {
  name = "git_runner_ecs"
  path = "/"
  tags = {
    Name        = "${var.ENV_NAME} Github runner ECS Task role"
    Environment = var.ENV_NAME
  }
  assume_role_policy = jsonencode(
    {
      "Version" : "2008-10-17",
      "Statement" : [
        {
          "Sid" : "",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "ecs-tasks.amazonaws.com"
          },
          "Action" : "sts:AssumeRole"
        }
      ]
    }
  )
}

resource "aws_iam_policy_attachment" "git_runner_ecs" {
  name       = "ssm-policy-attachment"
  roles      = [aws_iam_role.git_runner_ecs.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "git_runner_ecs" {
  name_prefix = "git_runner"
  role        = aws_iam_role.git_runner_ecs.name
  policy      = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      # Access to Github runner token
      {
        "Effect" : "Allow",
        "Action" : "secretsmanager:GetSecretValue",
        "Resource" : "arn:aws:secretsmanager:${data.aws_region.current.name}:*:secret:${var.ENV_NAME}-git-runner-*"
      },
    ]
  })
}

resource "aws_iam_role_policy" "git_runner_ecs_ec2" {
  name   = "git_runner_ecs_ec2"
  role   = aws_iam_role.git_runner.name
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      # Pass and Get IAM roles so that ECS agent can operate on behalf of given role
      {
        "Effect" : "Allow",
        "Action" : ["iam:GetRole", "iam:PassRole"],
        "Resource" : [aws_iam_role.git_runner.arn, aws_iam_role.git_runner_ecs.arn]
      },
    ]
  })
}

##########################################
# AWS ECS cluster
##########################################
resource "aws_ecs_cluster" "git_runner" {
  name = "${var.ENV_NAME}_git_runner"
  setting {
    name  = "containerInsights"
    value = "disabled"
  }
  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.git_runner.name
      }
    }
  }
  tags = {
    Name        = "${var.ENV_NAME}_git_runner"
    Environment = var.ENV_NAME
  }

}

##########################################
# AWS ECS Service
##########################################

resource "aws_ecs_service" "git_runner" {
  name            = "${var.ENV_NAME}_git_runner"
  launch_type     = "FARGATE"
  cluster         = aws_ecs_cluster.git_runner.arn
  task_definition = aws_ecs_task_definition.git_runner.arn
  network_configuration {
    assign_public_ip = true
    security_groups  = [
      aws_security_group.git_runner.id
    ]
    subnets = [
      aws_subnet.public.id
    ]
  }
  desired_count = 0
  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_ecs_service" "git_runner_external" {
  name            = "${var.ENV_NAME}_git_runner_ext"
  launch_type     = "EC2"
  cluster         = aws_ecs_cluster.git_runner.arn
  task_definition = aws_ecs_task_definition.git_runner_ext.arn
  desired_count   = 1
  lifecycle {
    ignore_changes = [desired_count]
  }
}


##########################################
# AWS ECS Task
##########################################
resource "aws_ecs_task_definition" "git_runner" {
  family                = "${var.ENV_NAME}_git_runner"
  task_role_arn         = aws_iam_role.git_runner_ecs.arn
  execution_role_arn    = aws_iam_role.git_runner_ecs.arn
  container_definitions = jsonencode([
    {
      name : "${var.ENV_NAME}_git_runner"
      image : "${aws_ecr_repository.git_runner.repository_url}:git-runner"
      logConfiguration : {
        logDriver : "awslogs"
        "options" : {
          "awslogs-group" : aws_cloudwatch_log_group.git_runner.name
          "awslogs-region" : data.aws_region.current.name
          "awslogs-stream-prefix" : "git_runner"
        }
      }
      environment : [
        {
          name : "ENV_NAME"
          value : var.ENV_NAME
        },
        {
          name : "RUNNER_NAME"
          value : "${var.ENV_NAME}-fg-git_runner"
        },
        {
          name : "GITHUB_OWNER"
          value : "${var.GITHUB_REPO.repo_owner}"
        },
        {
          name : "GITHUB_REPOSITORY"
          value : "${var.GITHUB_REPO.repo_name}"
        }
      ]
      secrets : [
        {
          "valueFrom" : data.aws_secretsmanager_secret.github-pat.arn
          "name" : "GITHUB_PAT"
        }
      ]
    }
  ]
  )
  cpu                      = "256"
  memory                   = "1024"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
}

resource "aws_ecs_task_definition" "git_runner_ext" {
  family                = "${var.ENV_NAME}_git_runner_ext"
  task_role_arn         = aws_iam_role.git_runner_ecs.arn
  execution_role_arn    = aws_iam_role.git_runner_ecs.arn
  container_definitions = jsonencode([
    {
      name : "${var.ENV_NAME}_git_runner_ext"
      image : "${aws_ecr_repository.git_runner.repository_url}:git-runner"
      logConfiguration : {
        logDriver : "awslogs"
        "options" : {
          "awslogs-group" : aws_cloudwatch_log_group.git_runner.name
          "awslogs-region" : data.aws_region.current.name
          "awslogs-stream-prefix" : "git_runner_ext"
        }
      }
      environment : [
        {
          name : "ENV_NAME"
          value : var.ENV_NAME
        },
        {
          name : "RUNNER_NAME"
          value : "${var.ENV_NAME}-ext-git_runner"
        },
        {
          name : "GITHUB_OWNER"
          value : "${var.GITHUB_REPO.repo_owner}"
        },
        {
          name : "GITHUB_REPOSITORY"
          value : "${var.GITHUB_REPO.repo_name}"
        }
      ]
      secrets : [
        {
          "valueFrom" : data.aws_secretsmanager_secret.github-pat.arn
          "name" : "GITHUB_PAT"
        }
      ]
    }
  ]
  )
  cpu                      = "256"
  memory                   = "256"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
}
