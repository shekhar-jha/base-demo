#!/usr/bin/env bash

cd /tmp
echo "Trying to enable SSM Agent..."
systemctl enable amazon-ssm-agent
echo "Trying to start SSM Agent..."
systemctl start amazon-ssm-agent

echo "Trying to update the instance..."
yum update -y

cd /

# install and start start docker
amazon-linux-extras install docker -y
service docker start

