
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

1. Create a AWS account
     ```
   aws iam create-user --user-name coreInfra --profile root-acct
   aws iam attach-user-policy --user-name coreInfra --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess" --profile root-acct
   aws iam create-access-key --user-name coreInfra --profile root-acct
   ```
2. Setup access key using `aws configure --profile core-infra` to be used for setup going forward
3. 

### Core infrastructure

The core infrastructure consists of terraform state storage (s3), GitHub action runner environment. The following steps were followed to create the core infra

1. 
