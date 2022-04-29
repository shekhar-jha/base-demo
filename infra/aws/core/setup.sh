#!/bin/bash

. ../../scripts/pgp.sh
. ../../scripts/cloud.sh
. ../../scripts/infra.sh

export TF_VAR_INFRA_CIDR="10.0.0.0/16"
usage() { echo "Usage: $0 -e <environment name> -c <aws profile> -r <aws region> [-d]" 1>&2; exit 1;}
while getopts ":e:c:r:d" options;
do
  case "${options}" in
    e)
      ENV_NAME="${OPTARG}"
      if [[ "${ENV_NAME}" == "" ]];
      then
        usage
      fi
      ;;
    c)
      CLOUD_PROFILE="${OPTARG}"
      if [[ "${CLOUD_PROFILE}" == "" ]];
      then
        usage
      fi
      ;;
    r)
      CLOUD_REGION="${OPTARG}"
      if [[ "${CLOUD_REGION}" == "" ]];
      then
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

if [[ "${ENV_NAME}" == "" ]];
then
  usage
fi
if [[ "${CLOUD_PROFILE}" == "" ]];
then
  usage
fi

export INFRA_CLOUD_TYPE='AWS'
export INFRA_IAC_TYPE='Terraform'
export ENV_NAME="${ENV_NAME:-NEW}"
export TF_DOWNLOAD_PLUGIN=${TF_DOWNLOAD_PLUGIN:-false}
export CLOUD_REGION="${CLOUD_REGION}"
env_name=$(echo "${ENV_NAME}" | tr '[:upper:]' '[:lower:]')
export env_name

CloudInit "${ENV_NAME}" "${INFRA_CLOUD_TYPE}" profile "${CLOUD_PROFILE}" "e" 2
PGPKeyExistsInStore "${env_name}" 'KEY' "${INFRA_CLOUD_TYPE}"; key_exists_in_store=$?
PGPKeyExistsInStore "${env_name}" 'PUB' "${INFRA_CLOUD_TYPE}"; pub_exists_in_store=$?
if [[ $key_exists_in_store -eq 1 ]] || [[ $pub_exists_in_store -eq 1 ]];
then
  echo "PGP keys don't exist in store"
  PGPKeyFileExists "${env_name}" 'KEY' '' r; key_file_exists=$?
  PGPKeyFileExists "${env_name}" 'PUB' '' r; pub_file_exists=$?
  if [[ $key_file_exists -ne 0 ]] && [[ $pub_file_exists -ne 0 ]];
  then
    echo "PGP key files are missing." 
    PGPCreateKeys "${env_name}"
  fi
  PGPStoreKeys "${env_name}" 'KEY' "${INFRA_CLOUD_TYPE}" '' 'e' 3
  PGPStoreKeys "${env_name}" 'PUB' "${INFRA_CLOUD_TYPE}" '' 'e' 4
  PGPDeleteKeyFile "${env_name}" 'KEY' '' 'e' 5
  PGPDeleteKeyFile "${env_name}" 'PUB' '' 'e' 6
fi

export INFRA_STORE_BUCKET=$(CloudGetResource "${env_name}" "${INFRA_CLOUD_TYPE}" "FileStore" "${env_name}-tf-state" )
InfraLoadState "${env_name}" "${INFRA_IAC_TYPE}" "${INFRA_CLOUD_TYPE}" "${INFRA_CLOUD_TYPE}" "${INFRA_STORE_BUCKET}" '' 'r' 11
InfraInit "${env_name}" "${INFRA_IAC_TYPE}" "${INFRA_CLOUD_TYPE}" '' 'e' 7
InfraApply "${env_name}" "${INFRA_IAC_TYPE}" 'Update' '' '' 'e' 8
APPLY_RET_CODE=$?
decryptedKey=$(InfraGetConfig "${env_name}" "aws_iam_user_access_key_secret_encrypt" "${INFRA_IAC_TYPE}" "${INFRA_CLOUD_TYPE}" '' 'e' 9)
bucketId=$(InfraGetConfig "${env_name}" "aws_s3_tf_state_id" "${INFRA_IAC_TYPE}" ''  '' 'e' 10)
if [[ $APPLY_RET_CODE -ne 1 ]];
then
  InfraSaveState "${env_name}" "${INFRA_IAC_TYPE}" "${INFRA_CLOUD_TYPE}" "${INFRA_CLOUD_TYPE}" "${bucketId}" '' 'e' 11
  InfraCleanup "${env_name}" "${INFRA_IAC_TYPE}" "${INFRA_CLOUD_TYPE}" '' 'e' 12
else
  echo "Skipping saving state since there is no change"
  InfraCleanup "${env_name}" "${INFRA_IAC_TYPE}" "${INFRA_CLOUD_TYPE}" '' 'e' 12
fi

echo "Decrypt: ${decryptedKey}"
echo "Bucket ID: ${bucketId}"

