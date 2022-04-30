##########################################
# AWS AMI data
##########################################
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name      = "owner-alias"
    values    = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

##########################################
# AWS EC2 Launch template & scaling group
##########################################

resource "aws_launch_template" "git_runner" {
  name_prefix            = "git_runner"
  description            = "Launch a VM to run Git runner"
  image_id               = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.micro"
  # No SSH Key is associated with instance.
# key_name
#  vpc_security_group_ids = [aws_security_group.git_runner.id]
  iam_instance_profile {
    name                 = aws_iam_instance_profile.git_runner.name
  }
  network_interfaces {
    device_index = 0
    associate_public_ip_address = "true"
    security_groups = [aws_security_group.git_runner.id]
    delete_on_termination = "true"
    description = "git_runner_vm_nic"
    subnet_id = aws_subnet.public.id
  }
  metadata_options {
    http_endpoint        = "enabled"
    http_put_response_hop_limit = 1
    http_tokens          = "required"
  }
  monitoring {
    enabled              = false
  }
  tag_specifications {
    resource_type        = "instance"
    tags = {
      Name               = "${var.ENV_NAME} git_runner"
      Environment        = var.ENV_NAME
    }
  }
  user_data              = base64encode(templatefile("${path.module}/setup-vm.sh.tpl", {
    region               = data.aws_region.current.name
    linux_type           = "linux_amd64"
  }))
}

resource "aws_autoscaling_group" "git_runner" {
  name_prefix         = "git_runner"
  max_size            = 1
  min_size            = 1
  health_check_type   = "EC2"
  desired_capacity    = 1
#  vpc_zone_identifier = [aws_subnet.public.id]

  lifecycle {
    create_before_destroy = true
  }
  launch_template {
    id      = aws_launch_template.git_runner.id
    version = "$Latest" # support other versions?
  }
}

##########################################
# AWS Security Group
##########################################

resource "aws_security_group" "git_runner" {
  name_prefix = "git_runner"
  description = "allow all outbound traffic from the Git runner"
  vpc_id      = aws_vpc.git_runner.id

  tags = {
    Name               = "${var.ENV_NAME} Github runner security group"
    Environment        = var.ENV_NAME
  }
}

resource "aws_security_group_rule" "git_runner_egress" {
  description = "allow all egress traffic"
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = -1
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.git_runner.id
}


##########################################
# IAM Policies
##########################################

resource "aws_iam_instance_profile" "git_runner" {
  name_prefix = "git_runner"
  role        =  aws_iam_role.git_runner.name
  tags = {
    Name               = "${var.ENV_NAME} Github runner Instance profile"
    Environment        = var.ENV_NAME
  }
}

resource "aws_iam_role" "git_runner" {
  name_prefix = "git_runner"
  path        = "/"
  tags = {
    Name               = "${var.ENV_NAME} Github runner Instance role"
    Environment        = var.ENV_NAME
  }

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "git_runner" {
  name_prefix = "git_runner"
  role        = aws_iam_role.git_runner.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListAllMyBuckets",
          "s3:PutObject"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetEncryptionConfiguration"
        ],
        "Resource": "*"
      },
      # TODO: Enable logging
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "ssm_policy" {
  name       = "ssm-policy-attachment"
  roles      = [aws_iam_role.git_runner.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}