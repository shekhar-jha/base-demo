#!/bin/bash

. ../../scripts/pgp.sh
. ../../scripts/aws.sh
. ../../scripts/infra.sh
. ../../scripts/tf.sh

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

export ENV_NAME="${ENV_NAME:-NEW}"
export TF_DOWNLOAD_PLUGIN=${TF_DOWNLOAD_PLUGIN:-false}
export CLOUD_REGION="${CLOUD_REGION:-us-east-1}"
env_name=$(echo "${ENV_NAME}" | tr '[:upper:]' '[:lower:]')
export env_name

IsAvailable Command tar "tar"

AWSInit "${ENV_NAME}" "${CLOUD_REGION}" profile "${CLOUD_PROFILE}"
if [[ $? -ne 0 ]];
then
  echo "Failed to setup AWS using profile ${CLOUD_PROFILE}"
  exit 2
fi

PGPKeyExistsInStore "${env_name}" 'KEY' 'AWS'
key_exists_in_store=$?
PGPKeyExistsInStore "${env_name}" 'PUB' 'AWS'
pub_exists_in_store=$?
if [[ $key_exists_in_store -eq 1 ]] || [[ $pub_exists_in_store -eq 1 ]];
then
  echo "PGP keys don't exist in store"
  PGPKeyFileExists "${env_name}" 'KEY'; key_file_exists=$?
  PGPKeyFileExists "${env_name}" 'PUB'; pub_file_exists=$?
  if [[ $key_file_exists -ne 0 ]] && [[ $pub_file_exists -ne 0 ]];
  then
    echo "PGP key files are missing." 
    PGPCreateKeys "${env_name}"
  fi
  PGPKeyFileExists "${env_name}" 'KEY'; key_file_exists=$?
  PGPKeyFileExists "${env_name}" 'PUB'; pub_file_exists=$?
  if [[ $key_file_exists -eq 0 ]] && [[ $pub_file_exists -eq 0 ]];
  then
    PGPStoreKeys "${env_name}" KEY AWS
    key_store_result=$?
    if [ $key_store_result -eq 0 ];
    then
      PGPDeleteKeyFile "${env_name}" KEY
    fi
    PGPStoreKeys "${env_name}" PUB AWS
    pub_store_result=$?
    if [ $pub_store_result -eq 0 ];
    then
      PGPDeleteKeyFile "${env_name}" pub
    fi
  fi
fi

tf_home=$(TFHome "${env_name}")
tf_home_ret_code=$?
if [ $tf_home_ret_code -ne 0 ];
then
  echo "Failed to locate Terraform home"
  exit 3
fi
if [ ! -d "${tf_home}" ];
then
  echo "No Terraform home exists at ${tf_home}"
  exit 4
fi

PGPGetKeyIfNotExists "${env_name}" 'PUB' 'AWS' "${tf_home}" 'Y'
InfraApply "${env_name}" 'Terraform'; infra_apply=$?
if [ $infra_apply -ne 0 ];
then
  echo "Failed to apply infrastructure changes due to error ${infra_apply}"
  exit 5
fi

encrypted_b64_access_key=$(TFGetConfig "${env_name}" "aws_iam_user_access_key_secret_encrypt"); get_config_ret_code=$?
if [[ $get_config_ret_code -ne 0 ]];
then
  echo "Failed to retrieve access key secret aws_iam_user_access_key_secret_encrypt due to error ${get_config_ret_code}"
  echo "${encrypted_b64_access_key}"
  exit 6
fi
PGPGetKeyIfNotExists "${env_name}" 'KEY' 'AWS' "${tf_home}" 'Y'
decryptedKey=$(echo "${encrypted_b64_access_key}"|base64 -d | PGPDecrypt "${env_name}" '' "${tf_home}" )
decryptedKey_ret_code=$?
if [[ $decryptedKey_ret_code -ne 0 ]];
then
  echo "Failed to decrypt key due to error ${decryptedKey_ret_code}"
  echo "${decryptedKey}"
  exit 7
fi
echo "Decrypt: ${decryptedKey}"
TFCleanup "${env_name}"
PGPDeleteKeyFile "${env_name}" KEY "${tf_home}"
PGPDeleteKeyFile "${env_name}" PUB "${tf_home}"



