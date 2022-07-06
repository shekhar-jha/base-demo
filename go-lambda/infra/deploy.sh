#!/bin/bash

. common/scripts/pgp.sh
. common/scripts/cloud.sh
. common/scripts/infra.sh
. common/scripts/gcp.sh

usage() {
  echo "Usage: $0 -e <environment name> -t <type: GCP|AWS> -c <GCP account name|AWS profile name> [-p <project id>] [-r <default region>] [-d]" 1>&2
  exit 1
}
while getopts ":e:t:c:p:r:d" options; do
  case "${options}" in
  e)
    ENV_NAME="${OPTARG}"
    if [[ "${ENV_NAME}" == "" ]]; then
      usage
    fi
    ;;
  t)
    INFRA_CLOUD_TYPE="${OPTARG}"
    if [[ "${ENV_NAME}" == "" ]]; then
      usage
    fi
    ;;
  c)
    CLOUD_ACCT="${OPTARG}"
    if [[ "${CLOUD_ACCT}" == "" ]]; then
      usage
    fi
    ;;
  p)
    CLOUD_PROJECT="${OPTARG}"
    if [[ "${CLOUD_PROJECT}" == "" ]]; then
      usage
    fi
    ;;
  r)
    CLOUD_DEFAULT_REGION="${OPTARG}"
    if [[ "${CLOUD_DEFAULT_REGION}" == "" ]]; then
      usage
    fi
    ;;

  d)
    TF_DOWNLOAD_PLUGIN=true
    ;;
  :)
    echo "Error: -${OPTARG} requires an argument."
    usage
    ;;
  *)
    usage
    ;;
  esac
done

if [[ "${ENV_NAME}" == "" ]]; then
  usage
fi
if [[ "${INFRA_CLOUD_TYPE}" == "" ]] || { [[ "${INFRA_CLOUD_TYPE}" != "GCP" ]] && [[ "${INFRA_CLOUD_TYPE}" != "AWS" ]]; }; then
  usage
fi
if [[ "${CLOUD_ACCT}" == "" ]]; then
  usage
fi

export INFRA_CLOUD_TYPE="${INFRA_CLOUD_TYPE}"
export INFRA_IAC_TYPE='Terraform'
export ENV_NAME="${ENV_NAME:-NEW}"
export TF_DOWNLOAD_PLUGIN=${TF_DOWNLOAD_PLUGIN:-false}
export CLOUD_REGION="${CLOUD_DEFAULT_REGION}"
env_name=$(echo "${ENV_NAME}" | tr '[:upper:]' '[:lower:]')
export env_name

CloudInit "${ENV_NAME}" "${INFRA_CLOUD_TYPE}" profile "${CLOUD_ACCT}" 'e' 1
export TF_VAR_AWS_ENV_AUTH="${CLOUD_PROFILE}"

if [[ ! -d "${env_name}_terraform" ]]; then
  INFRA_STORE_BUCKET=$(CloudGetResource "${env_name}" "${INFRA_CLOUD_TYPE}" "FileStore" "${env_name}-go-lambda-tf-state")
  export INFRA_STORE_BUCKET
  InfraLoadState "${env_name}" "${INFRA_IAC_TYPE}" "${INFRA_CLOUD_TYPE}" "${INFRA_CLOUD_TYPE}" "${INFRA_STORE_BUCKET}" '' 'r'
fi
InfraInit "${env_name}" "${INFRA_IAC_TYPE}" "${INFRA_CLOUD_TYPE}" '' 'e' 6 'aws'
InfraApply "${env_name}" "${INFRA_IAC_TYPE}" 'Update' '' '' 'r' 8
APPLY_RET_CODE=$?
bucketId=$(InfraGetConfig "${env_name}" "aws_s3_tf_state_id" "${INFRA_IAC_TYPE}" '' '' 'e' 7)
if [[ $APPLY_RET_CODE -ne 1 ]]; then
  echo "All changes applied."
#  echo "Deleting plugins to reduce size"
#  rm -rf "${env_name}_terraform/.plugins/"
#  rm -rf "${env_name}_terraform/lambdaMain" "${env_name}_terraform/lambdaMain.zip"
#  InfraSaveState "${env_name}" "${INFRA_IAC_TYPE}" "${INFRA_CLOUD_TYPE}" "${INFRA_CLOUD_TYPE}" "${bucketId}" '' 'e' 8
#  InfraCleanup "${env_name}" "${INFRA_IAC_TYPE}" "${INFRA_CLOUD_TYPE}" '' 'e' 9
else
  echo "Skipping saving state since there is no change"
#  InfraCleanup "${env_name}" "${INFRA_IAC_TYPE}" "${INFRA_CLOUD_TYPE}" '' 'e' 10
fi
