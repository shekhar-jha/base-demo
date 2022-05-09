#!/usr/bin/env bash

cd /opt/base_demo/
source ./.env

GITHUB_PAT=$(aws secretsmanager get-secret-value --region ${region} --secret-id "${env}-git-runner" --query "SecretString" --output=text)

mkdir github_runner
FILES=$(aws codecommit get-folder --region ${region} --repository-name ${code_repo} \
  --folder-path github_runner --query "files[].absolutePath" --output text)
for FILE in $FILES;
do
        echo "${FILE}"
  aws codecommit get-file --region ${region} --repository-name ${code_repo} \
  --file-path "${FILE}" --query "fileContent" \
  --output text |base64 -d > "${FILE}"
done

docker build --tag git-runner \
  github_runner/

docker run \
  -e RUNNER_NAME=${env}-git-runner \
  -e ENV_NAME=${env} \
  -e GITHUB_PAT=${GITHUB_PAT} \
  git-runner