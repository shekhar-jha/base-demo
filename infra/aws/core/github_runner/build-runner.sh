#!/usr/bin/env bash

echo "Executing build runner script...."
cd /opt/base_demo || exit
mkdir -p runlogs_archive

LOG_SUFFIX=$(date +"%Y%m%d_%H%M%S%Z")
LOG_FILE="runlogs_${LOG_SUFFIX}.log"

log() {
    echo "[$(date +'%Y/%m/%d %H:%M:%S %Z')] $1" >> "/opt/base_demo/${LOG_FILE}"
}

log "Started build running script..."
log "Trying to enable SSM Agent..."
systemctl enable amazon-ssm-agent
log "Trying to start SSM Agent..."
systemctl start amazon-ssm-agent

log "Trying to update the instance..."
yum update -y

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-agent-install.html
log "Disabling the docker repository"
amazon-linux-extras disable docker
log "Installing ECS Amazon Linux extra repository"
amazon-linux-extras install -y ecs
log "Setting cluster to ${CLUSTER}"
echo "ECS_CLUSTER=${CLUSTER}" >> /etc/ecs/ecs.config


# install and start start docker
# amazon-linux-extras install docker -y
log "Starting docker service..."
service docker start
log "Started docker service with response $?"

# cleanup
log "Cleaning up the installation stuff"
yum clean all
rm -rf /var/lib/apt/lists/*
rm -rf /var/cache/yum

source ./.env

log "Downloading the scripts from codecommit repository..."
mkdir github_runner
FILES=$(aws codecommit get-folder --region ${region} --repository-name ${code_repo} \
  --folder-path github_runner --query "files[].absolutePath" --output text)
for FILE in $FILES; do
  log "Downloading ${FILE}"
  aws codecommit get-file --region ${region} --repository-name ${code_repo} \
    --file-path "${FILE}" --query "fileContent" \
    --output text | base64 -d > "${FILE}"
  log "Downloaded with result $?"
done

log "Building the Github runner image"
docker build --tag git-runner \
  github_runner/
log "Built image with result $?"

log "Deleting existing Github runner image..."
aws ecr batch-delete-image   --repository-name "${AWS_ECR_NAME}" \
  --image-ids "imageTag=git-runner" --region ${region}
log "Deleted existing image with result $?"
aws ecr get-login-password --region "${region}" | docker login --username AWS --password-stdin "${AWS_ECR_URL}"
docker tag git-runner "${AWS_ECR_URL}:git-runner"
log "Pushing the Github runner image.."
docker push "${AWS_ECR_URL}:git-runner"
log "Pushed new image with result $?"

log "Retrieving the github PAT"
GITHUB_PAT=$(aws secretsmanager get-secret-value --region ${region} --secret-id "${env}-git-runner" --query "SecretString" --output=text)

log "Starting the Github runner image on VM..."
docker run -d \
  -e RUNNER_NAME=${env}-git-runner \
  -e ENV_NAME=${env} \
  -e GITHUB_PAT=${GITHUB_PAT} \
  git-runner
log "Started the Github runner image with result $?"

# Need to add --no-block since there is a dependency on cloud-init script
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-agent-install.html
log "Registering the EC2 instance with ECS"
sudo systemctl enable --no-block --now ecs

log "Completed build runner script"
mv runlogs_*.log runlogs_archive/

echo "Executed build runner script."
