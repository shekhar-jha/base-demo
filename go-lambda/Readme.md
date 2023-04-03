`go-lambda` explores the ability to use common code-base to run serverless in multi-cloud environment.
This currently support HTTP requests using AWS Lambda and GCP Cloud Run.

# Infrastructure

The following section provides details about how to set up the environment

# Pre-requisite

Ensure that the following tools are installed and setup

1. Git
2. Terraform
3. GNUpg (GPG)
4. base64
5. tar
6. gunzip/gzip
7. docker

In addition to that depending on the environment being created, one of the following tools must be available.

1. AWS CLI (aws)
2. GCP SDK (gcloud) including beta (`gcloud components install beta`)

## AWS

TODO: Add environment image

### Lambda deployment

The deployment script should be run from a machine with internet access to enable terraform to download plugins.

1. Ensure that a valid AWS profile has been configured with an identity having `AdministratorAccess` permission for
   initial setup.
2. If a new environment needs to be setup, run the following commands after replacing `<Environment name>` with name of
   the environment (without spaces and 3 letters), `<AWS profile>` with name of AWS profile to use to set up
   environment, and `<AWS region>` to identify the region to deploy. The `-d` triggers the download of `Terraform`
   plugins.

     ```bash
     git clone -b go-lambda --recursive git@github.com:shekhar-jha/base-demo.git
     cd base-demo/go-lambda/infra
     chmod +x setup.sh
    ./setup.sh -e <Environment name> -t AWS -c <AWS profile> -r <AWS region> -d 
     ```
   After execution, the URL of the new Lambda function will be printed for reference.
3. During development, the following command can be used to build and deploy code updates on as needed basis
     ```bash
     cd base-demo/go-lambda/infra
     chmod +x deploy.sh
     ./deploy.sh -e <Environment name> -t AWS -c <AWS profile> -r <AWS region> -d
     ```
4. Incase local developement needs to be performed, the `build.sh` command can be used
     ```bash
     cd base-demo/go-lambda/infra
     chmod +x build.sh
     ./build.sh -e <Environment name> -t AWS -l
     ```
5. If needed for validation, create API Gateway from web UI.

### Test

The setup can be invoked through various channels as identified below

#### Lambda Invoke

Lambda functions can be invoked directly through the AWS CLI and similar administration interface. Replace
the `<Profile Name>`, `<function name>` below to invoke the function.
```bash
aws --profile <Profile Name> lambda invoke --function-name <function name> --cli-binary-format raw-in-base64-out \
--payload '{ "Name": "Lambda Invoke Event"}' response.json; cat response.json; rm response.json
```
In order to test the async mode, pass `--invocation-type Event` parameter in the command above.

#### Functional URL

Lambda supports functional URLs that can be created for a particular function and used for invocation. Please replace
the `<Functional URL Prefix>` with the detail generated as part of output of `setup.sh` command above.

```bash
curl -v -X POST -d '{ "Name": "Functional URL" }'  \
  -H "Content-Type: application/json" https://<Functional URL Prefix>.lambda-url.us-east-1.on.aws/
```

#### API Gateway

If created, the following command can be used to invoke the Lambda function through API gateway after replacing
the `<generated>` and `<Lambda function name>`

```bash
curl -v -X POST -d '{ "Name": "API Gateway" }'  \
  -H "Content-Type: application/json" https://<generated>.execute-api.us-east-1.amazonaws.com/default/<Lambda function name>
```

## GCP

### Cloud Run deployment

The deployment script should be run from a machine with internet access to enable terraform to download plugins.

1. Ensure that either the following commands have been run or you have credential file to login during execution

     ```bash
     gcloud auth application-default login
     gcloud auth login
     ```
   Pass the `--no-launch-browser` option (Deprecated) to avoid launching the browser.
2. If a new environment needs to be setup, run the following commands after replacing `<Environment name>` with name of
   the environment (without spaces and 3 letters), `<GCP User: eg: cloud_user_p_3eeff465@linuxacademygclabs.com>` with
   name of GCP user to use to set up environment, `<Project Name>` with applicable project name and `<Region>` to
   identify the region to deploy. The `-d` triggers the download of `Terraform` plugins.

     ```bash
     git clone -b go-lambda --recursive git@github.com:shekhar-jha/base-demo.git
     cd base-demo/go-lambda/infra
     chmod +x setup.sh
    ./setup.sh -e <Environment name> -t GCP -c "<GCP User>" -p <Project Name> -r '<Region>' -d
     ```
   After execution, the URL of the new cloud run will be printed for reference.
3. During development, the following command can be used to build and deploy code updates on as needed basis
     ```bash
     cd base-demo/go-lambda/infra
     chmod +x deploy.sh
     ./deploy.sh -e <Environment name> -t AWS -c <AWS profile> -r <AWS region> -d
     ```

### Test

The setup can be invoked using `curl` command as indicated above for testing AWS Lambda



