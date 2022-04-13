
# base-demo
Demonstrate development using terraform on AWS.


## Development Installation and Configuration

The following section provides details about how to setup development environment

### Pre-requisite

Ensure that the following tools are installed and setup

1. Git
2. Terraform
3. Go
4. Awscli
5. gnupg

#### Environment setup

1. Ensure that a valid AWS profile has been configured
2. If a new environment needs to be setup, run the following commands after replacing `<Environment name>` with name of the environment (without spaces) and `<AWS profile>` with name of AWS profile to use to setup environment.
     ```
     git clone https://github.com/shekhar-jha/base-demo.git 
     cd base-demo/infra/aws/core 
     chmod +x setup.sh
     ./setup.sh -e <Environment name> -c <AWS profile> -d
     ```

### Core infrastructure

The core infrastructure consists of terraform state storage (s3), GitHub action runner environment. The following steps were followed to create the core infra
