#!/usr/bin/env bash

cd /tmp
echo "Trying to enable SSM Agent..."
systemctl enable amazon-ssm-agent
echo "Trying to start SSM Agent..."
systemctl start amazon-ssm-agent

echo "Trying to update the instance..."
yum update -y

# install and start start docker
amazon-linux-extras install docker -y
service docker start
# cleanup
yum clean all
rm -rf /var/lib/apt/lists/*

mkdir -p /opt/base_demo
cd /opt/base_demo
# export input parameters as environment variable for scripts
echo "export region=${region}" > ./.env
{
 echo "export code_repo=${code_repo}"
 echo "export env=${env}"
 echo "export GITHUB_RUNNER_VERSION=${GITHUB_RUNNER_VERSION}"
 echo "export AWS_ECR_URL=${ecr_url}"
} >> ./.env
source ./.env

aws codecommit get-file --region ${region} --repository-name ${code_repo} \
  --file-path github_runner/build-runner.sh --query "fileContent"  \
  --output text |base64 -d > build-runner.sh
chmod +x build-runner.sh
./build-runner.sh
