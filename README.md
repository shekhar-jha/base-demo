
This project demonstrates development using terraform for multi-cloud scenarios across AWS and GCP.

# Development Infrastructure

The following section provides details about how to setup development environment

# Pre-requisite

Ensure that the following tools are installed and setup

1. Git
2. Terraform
3. GNUpg (GPG)
4. base64
5. tar
6. gunzip/gzip

In addition to that depending on the environment being created, one of the following tools must be available.

1. AWS CLI (aws)
2. GCP SDK (gcloud)

## AWS

TODO: Add environment image

### Environment setup

The environment setup should be run from a machine with internet access to enable terraform to download plugins.

1. Ensure that a valid AWS profile has been configured with an identity having `AdministratorAccess` permission for initial setup.
2. Set the environment variable `GITHUB_TOKEN` to Github PAT with `repo` permission to update repo environment variables.
3. If a new environment needs to be setup, run the following commands after replacing `<Environment name>` with name of
   the environment (without spaces and 3 letters), `<AWS profile>` with name of AWS profile to use to setup environment,
   and `<AWS region>` to identify the region to deploy.

     ```bash
     git clone -b infra-core --recursive git@github.com:shekhar-jha/base-demo.git
     cd base-demo/infra/aws/core 
     chmod +x setup.sh
     ./setup.sh -e <Environment name> -c <AWS profile> -r <AWS region> -d
     ```
   This will ensure that all the dependencies are created and initial state and keys will be saved for future reference.
   The `-d` triggers the download of `Terraform` plugins.
4. After initial deployment, please set the `RUNNER_PAT` environment secret with a Github PAT with `manage_runners:enterprise`
   and `public_repo` access.
5. Most of the build process involves creation of AWS components. The last part involves building the EC2 environment to
   build images and run git-runner. In order to debug this process, connect to EC2 instance (using SSM) and check the build process
   ```bash
   $ aws --profile <AWS profile> --region <AWS Region> \
     ssm start-session --target <instance id>

   Starting session with SessionId: CORE_INFRA-█████████████████
   sh-4.2$ sudo bash
   [root@ip-██-█-█-███ bin]# cd /opt/base_demo/
   [root@ip-██-█-█-███ base_demo]# tail -f runlogs_20220530_214236UTC.log 
   [2022/05/30 21:43:23 UTC] Started docker service with response 0
   [2022/05/30 21:43:23 UTC] Cleaning up the installation stuff
   [2022/05/30 21:43:28 UTC] Downloading the scripts from codecommit repository...
   [2022/05/30 21:43:33 UTC] Downloading github_runner/Dockerfile
   [2022/05/30 21:43:34 UTC] Downloaded with result 0
   [2022/05/30 21:43:34 UTC] Downloading github_runner/build-runner.sh
   [2022/05/30 21:43:35 UTC] Downloaded with result 0
   [2022/05/30 21:43:35 UTC] Downloading github_runner/entrypoint.sh
   [2022/05/30 21:43:35 UTC] Downloaded with result 0
   [2022/05/30 21:43:35 UTC] Building the Github runner image
   [2022/05/30 21:46:00 UTC] Built image with result 0
   [2022/05/30 21:46:00 UTC] Deleting existing Github runner image...
   [2022/05/30 21:46:01 UTC] Deleted existing image with result 0
   [2022/05/30 21:46:02 UTC] Pushing the Github runner image..
   [2022/05/30 21:47:50 UTC] Pushed new image with result 0
   [2022/05/30 21:47:50 UTC] Registering the EC2 instance with ECS
   [2022/05/30 21:47:51 UTC] Completed build runner script
   ```
   The output above shows successful run. If everything completes successfully, the ECS Instances tab of
   ECS cluster created will have an entry for the server.
6. Update the infrastructure using `apply.sh`
     ```bash
     cd base-demo/infra/aws/core 
     chmod +x apply.sh
     ./apply.sh -e <Environment name> -c <AWS profile> -r <AWS region> 
     ```
   Note that `-d` is not passed during apply since the plugins are stored as part of state package.

### Environment cleanup

Environment can be destroyed and cleaned up using `destroy.sh` script.
```bash
cd base-demo/infra/aws/core
chmod +x destroy.sh
./destroy.sh -e <Environment name> -c <AWS profile> -r <AWS region>
```

# GCP

The GCP environment consists of the following components
TODO: Image and description

## Environment setup

The environment setup should be run from a machine with internet access to enable terraform to download plugins.

1. Ensure that either the following command has been run or you have credential file to login during execution
   ```google cloud
   gcloud auth application-default login
   gcloud auth login
   ```
2. Set the environment variable `GITHUB_TOKEN` to Github PAT with `repo` permission to update repo environment variables.
3. If a new environment needs to be setup, run the following commands after replacing `<Environment name>` with name of
   the environment (without spaces and 3 letters), `<Project>` with name of GCP project to use to setup environment,
   and `<GCP region>` to identify the region to deploy.

     ```bash
     git clone -b infra-core --recursive git@github.com:shekhar-jha/base-demo.git     git checkout infra-core
     cd base-demo/infra/gcp/core 
     chmod +x g-setup.sh
     ./g-setup.sh -e <Environment name> -p <Project> -r <GCP region> -d
     ```
   This will ensure that all the dependencies are created and initial state and keys will be saved for future reference.
   The `-d` triggers the download of `Terraform` plugins. Due to the current approach,
4. After running the command for first time, the secret will be enabled. After which the Github PAT for registering the 
   Github runner token needs to be created with name `github_pat-<github repo owner>-<github repo name>` and corresponding
   token value in the same region as specified in the call above.
5. Invoke the `g-setup.sh` command again to set-up and trigger the github runner image build process 
   ```bash
     ./g-setup.sh -e <Environment name> -p <Project> -r <GCP region> -d
     ```
6. After the image creation is complete, invoke the above `g-setup.sh` command again to create the Cloud run job and other dependencies.
7. Manually invoke the `GCP Git-runner test` action workflow on the Github with environment name same as above to validate 
   the setup is working correctly.