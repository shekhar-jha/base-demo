#!/bin/bash

. ../../common/scripts/pgp.sh
. ../../common/scripts/cloud.sh
. ../../common/scripts/infra.sh
. ../../common/scripts/gcp.sh

usage() {
  echo "Usage: $0 -e <environment name> [-c <service account name>] [-p <project id>] [-r <default region>] [-d]" 1>&2
  exit 1
}
while getopts ":e:c:p:r:d" options; do
  case "${options}" in
  e)
    ENV_NAME="${OPTARG}"
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

export INFRA_CLOUD_TYPE='GCP'
export INFRA_IAC_TYPE='Terraform'
export ENV_NAME="${ENV_NAME:-NEW}"
export TF_DOWNLOAD_PLUGIN=${TF_DOWNLOAD_PLUGIN:-false}
env_name=$(echo "${ENV_NAME}" | tr '[:upper:]' '[:lower:]')
export env_name

CloudSetConfig "${env_name}" "${INFRA_CLOUD_TYPE}" "project" "${CLOUD_PROJECT}" '' 'e' 4
CloudSetConfig "${env_name}" "${INFRA_CLOUD_TYPE}" "replication-policy" "user-managed" 'secrets' 'e' 5
CloudSetConfig "${env_name}" "${INFRA_CLOUD_TYPE}" "locations" "${CLOUD_DEFAULT_REGION}" 'secrets' 'e' 6
export TF_VAR_GCP_PROJECT="${CLOUD_PROJECT}"
export TF_VAR_GCP_REGION="${CLOUD_DEFAULT_REGION}"
CloudInit "${env_name}" "${INFRA_CLOUD_TYPE}" 'adc' '' 'e' 2
GCPActivate "${env_name}" "secrets" 'e' 3
PGPKeyExistsInStore "${env_name}" 'KEY' "${INFRA_CLOUD_TYPE}"
key_exists_in_store=$?
PGPKeyExistsInStore "${env_name}" 'PUB' "${INFRA_CLOUD_TYPE}"
pub_exists_in_store=$?
if [[ $key_exists_in_store -eq 1 ]] || [[ $pub_exists_in_store -eq 1 ]]; then
  echo "PGP keys don't exist in store"
  PGPKeyFileExists "${env_name}" 'KEY' '' r
  key_file_exists=$?
  PGPKeyFileExists "${env_name}" 'PUB' '' r
  pub_file_exists=$?
  if [[ $key_file_exists -ne 0 ]] && [[ $pub_file_exists -ne 0 ]]; then
    echo "PGP key files are missing."
    PGPCreateKeys "${env_name}"
  fi
  PGPStoreKeys "${env_name}" 'KEY' "${INFRA_CLOUD_TYPE}" '' 'e' 7
  PGPStoreKeys "${env_name}" 'PUB' "${INFRA_CLOUD_TYPE}" '' 'e' 8
  PGPDeleteKeyFile "${env_name}" 'KEY' '' 'e' 9
  PGPDeleteKeyFile "${env_name}" 'PUB' '' 'e' 10
fi
INFRA_STORE_BUCKET=$(CloudGetResource "${env_name}" "${INFRA_CLOUD_TYPE}" "FileStore" "${env_name}-tf-state" 'r')
bucket_ret_val=$?
if [[ $bucket_ret_val -eq 0 ]]; then
  export INFRA_STORE_BUCKET
  InfraLoadState "${env_name}" "${INFRA_IAC_TYPE}" "${INFRA_CLOUD_TYPE}" "${INFRA_CLOUD_TYPE}" "${INFRA_STORE_BUCKET}" '' 'r' 12
fi
InfraInit "${env_name}" "${INFRA_IAC_TYPE}" "${INFRA_CLOUD_TYPE}" '' 'e' 7
InfraApply "${env_name}" "${INFRA_IAC_TYPE}" 'Update' '' '' 'r' 8
APPLY_RET_CODE=$?
bucketId=$(InfraGetConfig "${env_name}" "STATE_BUCKET_ID" "${INFRA_IAC_TYPE}" '' '' 'r' 10)
if [[ $APPLY_RET_CODE -ne 1 ]]; then
  InfraSaveState "${env_name}" "${INFRA_IAC_TYPE}" "${INFRA_CLOUD_TYPE}" "${INFRA_CLOUD_TYPE}" "${bucketId}" '' 'e' 11
  InfraCleanup "${env_name}" "${INFRA_IAC_TYPE}" "${INFRA_CLOUD_TYPE}" '' 'e' 12
else
  echo "Skipping saving state since there is no change"
  InfraCleanup "${env_name}" "${INFRA_IAC_TYPE}" "${INFRA_CLOUD_TYPE}" '' 'e' 12
fi
