
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

The environment setup should be run from a machine with internet access to enable terraform to download plugins.

1. Ensure that a valid AWS profile has been configured
2. If a new environment needs to be setup, run the following commands after replacing `<Environment name>` with name of the environment (without spaces) and `<AWS profile>` with name of AWS profile to use to setup environment.
     ```
     git clone https://github.com/shekhar-jha/base-demo.git 
     cd base-demo/infra/aws/core 
     chmod +x setup.sh
     ./setup.sh -e <Environment name> -c <AWS profile> -d
     ```
     This will ensure that all the dependencies are created and initial state and keys will be saved for future reference.

### Core infrastructure

Any changes to the core-infrastructure can be applied by using `apply.sh` command.


### Environment cleanup

Environment can be destroyed and cleaned up using `destroy.sh -e <env name> -c <profile name>` script.