locals {
  aws_name_suffix="${local.env_name_lower}-infra-${random_string.ENV_SUFFIX.result}"
  aws_subnet_cidr_blocks = cidrsubnets(var.INFRA_CIDR, 4, 4, 4, 4)
}

##############################################
# VPC
##############################################
resource "aws_vpc" "git_runner" {
  cidr_block        = var.INFRA_CIDR
  instance_tenancy  = "default"
  enable_dns_hostnames = true
  enable_dns_support = true
  enable_classiclink = false
  enable_classiclink_dns_support = false
  assign_generated_ipv6_cidr_block = false

  tags = {
    Name = "${local.env_name_lower}_git_runner_vpc"
    Environment = local.env_name_lower
  }
}

##############################################
# Default security group
##############################################
# resource "aws_default_security_group" "git_runner" {
#  vpc_id = aws_vpc.git_runner.id
#  ingress {
#    protocol   = -1
#    self       = true
#    from_port  = 0
#    to_port    = 0
#    description= "Allow internal traffic"
#  }
#  tags = {
#    Name = "${local.env_name_lower}_git_runner_vpc_sg_default"
#    Environment = "${local.env_name_lower}"
#  }
# }

##############################################
# DHCP Options set
##############################################

# resource "aws_vpc_dhcp_options" "git_runner" {
#   domain_name          = "my-domain.com"e
#   domain_name_servers  = "8.8.8.8"
#   ntp_servers          = "0.pool.ntp.org"
#   netbios_name_servers = ""
#   netbios_node_type    = ""
# }

##############################################
# Internet Gateway
# Provided for public subnet
##############################################

resource "aws_internet_gateway" "git_runner" {
  vpc_id = aws_vpc.git_runner.id

  tags = {
    Name = "${local.env_name_lower}_git_runner_vpc_igw"
    Environment = local.env_name_lower
  }
}

##############################################
# Routes
##############################################

# Default route table does not have any route to ensure
# that new subnets don't start routing traffics.
resource "aws_default_route_table" "git_runner" {
  default_route_table_id = aws_vpc.git_runner.default_route_table_id
  route = []
  tags  = {
    Name = "${local.env_name_lower}_git_runner_vpc_rt"
    Environment = local.env_name_lower
  }
}

# Public route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.git_runner.id
  tags   = {
    Name = "${local.env_name_lower}_git_runner_rt_pub"
    Environment = local.env_name_lower
  }
}

# Public route table route to connect to internet gateway
# Note: You still need EIP attached to a NAT Gateway/Instance, network interface
# of EC2 instance or equivalent to route traffic to internet
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.git_runner.id
}

# Private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.git_runner.id
  tags   = {
    Name = "${local.env_name_lower}_git_runner_rt_pvt"
    Environment = local.env_name_lower
  }
}

##############################################
# Subnets
##############################################

# Public subnet
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.git_runner.id
  cidr_block = local.aws_subnet_cidr_blocks[0]
  tags   = {
    Name = "${local.env_name_lower}_git_runner_public_subnet"
    Environment = local.env_name_lower
  }
}

# Private subnet
resource "aws_subnet" "private" {
  vpc_id = aws_vpc.git_runner.id
  cidr_block = local.aws_subnet_cidr_blocks[1]
  tags   = {
    Name = "${local.env_name_lower}_git_runner_private_subnet"
    Environment = local.env_name_lower
  }
}

##############################################
# Network ACLs
##############################################

# Default NACL allows all traffic
# TODO: Need to restrict traffic
resource "aws_default_network_acl" "git_runner" {
  default_network_acl_id=aws_vpc.git_runner.default_network_acl_id
  subnet_ids = null
  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  tags   = {
    Name = "${local.env_name_lower}_git_runner_nacl"
    Environment = local.env_name_lower
  }
  lifecycle {
      ignore_changes = [subnet_ids]
  }
}

##############################################
# Elastic Public IP
# This can be associated with either NAT gateway or
# EC2 instance
##############################################

#resource "aws_eip" "git_runner" {
#  vpc = true
#  tags   = {
#    Name = "${local.env_name_lower}_git_runner_eip"
#    Environment = local.env_name_lower
#  }
#}

##############################################
# NAT Gateway
# Costs money to run
##############################################

# resource "aws_nat_gateway" "git_runner" {
#  allocation_id = aws_eip.git_runner.id
#  subnet_id = aws_subnet.public.id
#  tags   = {
#    Name = "${local.env_name_lower}_git_runner_nat_gw"
#    Environment = local.env_name_lower
#  }
# }

##############################################
# Route table association
##############################################

resource "aws_route_table_association" "private" {
  subnet_id = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public" {
  subnet_id = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

##############################################
# VPC Endpoints for AWS operations
##############################################

resource "aws_vpc_endpoint" "git_runner_ssm" {
  service_name = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_id = aws_vpc.git_runner.id
  vpc_endpoint_type = "Interface"
  subnet_ids = [aws_subnet.private.id]
  private_dns_enabled = true
  security_group_ids = [aws_security_group.git_runner.id]
  tags   = {
    Name = "${local.env_name_lower}_git_runner_ssm"
    Environment = local.env_name_lower
  }
# TODO: Add restricted policy to reduce impact
}

resource "aws_vpc_endpoint" "git_runner_ssmmessages" {
  service_name = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_id = aws_vpc.git_runner.id
  vpc_endpoint_type = "Interface"
  subnet_ids = [aws_subnet.private.id]
  private_dns_enabled = true
  security_group_ids = [aws_security_group.git_runner.id]
  tags   = {
    Name = "${local.env_name_lower}_git_runner_ssm_messages"
    Environment = local.env_name_lower
  }
  # TODO: Add restricted policy to reduce impact
}

resource "aws_vpc_endpoint" "git_runner_ec2" {
  service_name = "com.amazonaws.${data.aws_region.current.name}.ec2"
  vpc_id = aws_vpc.git_runner.id
  vpc_endpoint_type = "Interface"
  subnet_ids = [aws_subnet.private.id]
  private_dns_enabled = true
  security_group_ids = [aws_security_group.git_runner_endpoint.id]
  tags   = {
    Name = "${local.env_name_lower}_git_runner_ec2"
    Environment = local.env_name_lower
  }
  # TODO: Add restricted policy to reduce impact
}

resource "aws_vpc_endpoint" "git_runner_s3" {
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_id = aws_vpc.git_runner.id
  route_table_ids = [aws_route_table.private.id]
# Policy to restrict access to Yum repos for AWS Linux 2
  policy = jsonencode({
    "Statement": [
      {
        "Principal": "*",
        "Action": [
          "s3:GetObject"
        ],
        "Effect": "Allow",
        "Resource": [
          "arn:aws:s3:::amazonlinux.${data.aws_region.current.name}.amazonaws.com/*",
          "arn:aws:s3:::amazonlinux-2-repos-${data.aws_region.current.name}/*"
        ]
      },
    ]
  })
  tags   = {
    Name = "${local.env_name_lower}_git_runner_s3"
    Environment = local.env_name_lower
  }
}


##############################################
# Security group for VPC Endpoint services
##############################################

resource "aws_security_group" "git_runner_endpoint" {
  name_prefix = "git_runner_endpoint"
  description = "allow inbound traffic from the network"
  vpc_id      = aws_vpc.git_runner.id

  tags = {
    Name               = "${var.ENV_NAME} git_runner endpoint security group"
    Environment        = var.ENV_NAME
  }
}

# Only ingress traffic is supported.
resource "aws_security_group_rule" "git_runner_endpoint_ingress" {
  description = "allow all ingress traffic"
  type        = "ingress"
  from_port   = 0
  to_port     = 0
  protocol    = -1
  # TODO: Reduce cidr_blocks to subnet cidr to reduce chance of reuse
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.git_runner_endpoint.id
}


##############################################
# Defaults
# This creates a new Default VPC
##############################################

# resource "aws_default_vpc" "git_runner" {

#  enable_dns_support   = true
#  enable_dns_hostnames = true
#  enable_classiclink   = false

#  tags   = {
#    Name = "${local.env_name_lower}_git_runner_vpc_default"
#    Environment = "${local.env_name_lower}"
#  }
# }