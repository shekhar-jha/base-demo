#!/usr/bin/env bash

mkdir -p /opt/base_demo
cd /opt/base_demo
# export input parameters as environment variable for scripts
echo "export region=${region}" > ./.env
{
 echo "export code_repo=${code_repo}"
 echo "export env=${env}"
 echo "export GITHUB_RUNNER_VERSION=${GITHUB_RUNNER_VERSION}"
 echo "export AWS_ECR_URL=${ecr_url}"
 echo "export AWS_ECR_NAME=${ecr_name}"
 echo "export CLUSTER=${culster_name}"
 echo "export IAM_ROLE=${iam_role}"
 echo "export GITHUB_OWNER=${GITHUB_OWNER}"
 echo "export GITHUB_REPO=${GITHUB_REPO}"
} >> ./.env
source ./.env

aws codecommit get-file --region ${region} --repository-name ${code_repo} \
  --file-path github_runner/build-runner.sh --query "fileContent"  \
  --output text |base64 -d > build-runner.sh
chmod +x build-runner.sh
./build-runner.sh
