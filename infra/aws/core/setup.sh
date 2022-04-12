#!/bin/bash

. ../../scripts/pgp.sh
. ../../scripts/aws.sh
. ../../scripts/infra.sh
. ../../scripts/tf.sh

export ENV_NAME="NEW"
export TF_DOWNLOAD_PLUGIN=true
export env_name=$(echo "${ENV_NAME}" | tr '[:upper:]' '[:lower:]')

# export NEW_AWS_ACCESS_KEY_ID=AKIAZR5HGZTVFVXRQ2LW
# export NEW_AWS_ACCESS_KEY_SECRET=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
# export NEW_AWS_PROFILE=core-infra
# export AWS_DEFAULT_REGION='us-east-1'
# export AWS_REGION='us-east-1'
AWSInit NEW 'us-east-1' profile core-infra

PGPKeyExistsInStore "${env_name}" 'KEY' 'AWS'
key_exists_in_store=$?
PGPKeyExistsInStore "${env_name}" 'PUB' 'AWS'
pub_exists_in_store=$?
if [ $key_exists_in_store -eq 1 -o $pub_exists_in_store -eq 1 ];
then
  echo "PGP keys don't exist in store"
  PGPKeyFileExists "${env_name}" 'KEY'; key_file_exists=$?
  PGPKeyFileExists "${env_name}" 'PUB'; pub_file_exists=$?
  if [ $key_file_exists -ne 0 -a $pub_file_exists -ne 0 ];
  then
    echo "PGP key files are missing." 
    PGPCreateKeys "${env_name}"
  fi
  PGPKeyFileExists "${env_name}" 'KEY'; key_file_exists=$?
  PGPKeyFileExists "${env_name}" 'PUB'; pub_file_exists=$?
  if [ $key_file_exists -eq 0 -a $pub_file_exists -eq 0 ];
  then
    PGPStoreKeys ${env_name} KEY AWS
    key_store_result=$?
    if [ $key_store_result -eq 0 ];
    then
      PGPDeleteKeyFile ${env_name} KEY
    fi
    PGPStoreKeys ${env_name} PUB AWS
    pub_store_result=$?
    if [ $pub_store_result -eq 0 ];
    then
      PGPDeleteKeyFile ${env_name} pub
    fi
  fi
fi

tf_home=$(TFHome "${env_name}")
tf_home_ret_code=$?
if [ $tf_home_ret_code -ne 0 ];
then
  echo "Failed to locate Terraform home"
  exit
fi
if [ ! -d "${tf_home}" ];
then
  echo "No Terraform home exists at ${tf_home}"
  exit
fi
PGPKeyFileExists "${env_name}" 'PUB' "${tf_home}"; pub_file_exists=$?
if [ $pub_file_exists -eq 1 ];
then
  PGPGetKey "${env_name}" 'PUB' 'AWS' "${tf_home}"
fi

InfraApply "${env_name}" 'Terraform'; infra_apply=$?
if [ $infra_apply -eq 0 ];
then
  encrypted_b64_access_key=$(TFGetConfig "${env_name}" "aws_iam_user_access_key_secret_encrypt")
  get_config_ret_code=$?
  if [[ $get_config_ret_code -ne 0 ]];
  then
    echo "Failed to retrieve access key secret aws_iam_user_access_key_secret_encryp1t due to error ${get_config_ret_code}"
    echo "${encrypted_b64_access_key}"
    exit
  fi
  PGPKeyFileExists "${env_name}" 'KEY' "${tf_home}"; key_file_exists=$? 
  if [ $key_file_exists -eq 1 ];
  then
    PGPGetKey "${env_name}" 'KEY' 'AWS' "${tf_home}"
  fi
  decryptedKey=$(echo "${encrypted_b64_access_key}"|base64 -d | PGPDecrypt "${env_name}" '' "${tf_home}" )
  decryptedKey_ret_code=$?
  if [[ $decryptedKey_ret_code -ne 0 ]];
  then
    echo "Failed to decrypt key due to error ${decryptedKey_ret_code}"
    echo "${decryptedKey}"
    exit
  fi
  echo "Decrypt: ${decryptedKey}"
  TFCleanup "${env_name}"
  PGPDeleteKeyFile "${env_name}" KEY "${tf_home}" 
  PGPDeleteKeyFile "${env_name}" PUB "${tf_home}" 
fi

