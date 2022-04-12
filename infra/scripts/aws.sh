SCRIPT_DEFAULT_HOME=$(cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}" )" &> /dev/null && pwd)
AWS_DEFAULT_HOME=$(pwd)
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:us-east-2}"

. "${SCRIPT_DEFAULT_HOME}"/basic.sh

function AWSInit {
  if [ "${1}" == "" ];
  then
    echo "AWSInit <Scope> [<region: us-east-2>] [<Authentication type: env*|profile>] [<profile name>]" 
    return -1
  fi
  IsAvailable c aws "AWS CLI"
  local AWS_INIT_SCOPE="${1}"
  local AWS_REGION_NAME="${2}"
  local AWS_AUTH_TYPE="${3}"
  local AWS_PROFILE_NAME="${4}"
  local AWS_ACCESS_KEY_ENV_NAME="${AWS_INIT_SCOPE}_AWS_ACCESS_KEY_ID"
  local AWS_ACCESS_SECRET_ENV_NAME="${AWS_INIT_SCOPE}_AWS_ACCESS_KEY_SECRET"
  local AWS_REGION_ENV_NAME="${AWS_INIT_SCOPE}_AWS_REGION"
  local AWS_PROFILE_ENV_NAME="${AWS_INIT_SCOPE}_AWS_PROFILE"

  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_PROFILE
  unset AWS_DEFAULT_REGION
  unset AWS_REGION
  case "${AWS_AUTH_TYPE}" in

    profile)
      local aws_profile_name_env_value="${!AWS_PROFILE_ENV_NAME}"
      local aws_profile_name="${AWS_PROFILE_NAME:-$aws_profile_name_env_value}"
      if [ "${aws_profile_name}" != "" ];
      then
        aws_auth_profiles=$(aws configure list-profiles)
        if [[ ! "${aws_auth_profiles}" =~ "${aws_profile_name}" ]];
        then
          echo "AWSInit: Given AWS profile ${aws_profile_name} is not configured in the environment. Please run 'aws configure' to create a matching profile"
          return -3
        fi
        export AWS_PROFILE=${aws_profile_name}
        echo "AWSInit: AWS Environment ${AWS_INIT_SCOPE} is setup using profile ${AWS_PROFILE}"
      else
        # TODO: Handle default profile
        echo "AWSInit: No AWS profile specified for configuration. Please pass the profile name either as parameter or environment variable ${AWS_PROFILE_ENV_NAME}"
        return -4
      fi
      ;;

    'env'|*)
      local env_aws_access_key_id="${!AWS_ACCESS_KEY_ENV_NAME}"
      local env_aws_access_key_secret="${!AWS_ACCESS_SECRET_ENV_NAME}"
      if [ "${env_aws_access_key_id}" != "" ] && [ "${env_aws_access_key_secret}" != "" ];
      then
        export AWS_ACCESS_KEY_ID="${env_aws_access_key_id}"
        export AWS_SECRET_ACCESS_KEY="${env_aws_access_key_secret}"
        echo "AWSInit: AWS Environment ${AWS_INIT_SCOPE} is setup using AWS Access key ${AWS_ACCESS_KEY_ID}"
      else
        echo "AWSInit: No environment variable (${AWS_ACCESS_KEY_ENV_NAME}=${env_aws_access_key_id:-<empty string>} & ${AWS_ACCESS_SECRET_ENV_NAME}=****) could be located"
        return -2
      fi
      ;;
    
  esac
  aws_caller_id_status=$(aws sts get-caller-identity 2>&1)
  local aws_caller_ret_code=$?
  if [ $aws_caller_ret_code -ne 0 ];
  then
    echo "AWSInit: Failed to validate AWS authentication setup. Error code: ${aws_caller_ret_code}"
    echo "${aws_caller_id_status}"
    return -5
  else
    echo "AWSInit: AWS authentication is setup." 
  fi
  local aws_selected_region_env_value="${!AWS_REGION_ENV_NAME}"
  local aws_selected_region="${AWS_REGION_NAME:-$aws_selected_region_env_value}"
  if [ "${aws_selected_region}" != "" ];
  then
    export AWS_DEFAULT_REGION=${aws_selected_region:-$AWS_DEFAULT_REGION}
    export AWS_REGION=${aws_selected_region:-$AWS_DEFAULT_REGION}
    echo "AWSInit: AWS Environment ${AWS_INIT_SCOPE} is setup for region ${AWS_DEFAULT_REGION}"
  else
    if [ ! "${AWS_PROFILE}" == "" ];
    then
      local profile_region
      profile_region=$(aws configure get profile."${AWS_PROFILE}".region)
      if [ "${profile_region}" == "" ];
      then
        echo "AWSInit: No AWS default region specified for profile. Please pass the region name either as parameter, environment variable ${AWS_PROFILE_ENV_NAME} or as part of profile ${AWS_PROFILE} configuration."    
        return -6
      else
        echo "AWSInit: Profile ${AWS_PROFILE} region set to ${profile_region}"
      fi
    else
      echo "AWSInit: No AWS default region specified for configuration. Please pass the region name either as parameter or environment variable ${AWS_PROFILE_ENV_NAME}"    
      return -7
    fi
  fi
}

function AWSContainsKey {
  if [ "${1}" == "" ] || [ "${2}" == "" ];
  then
    echo 'AWSContainsKey <Scope> <Key name>'
    return -1
  fi
  local AWS_SECRET_SCOPE="${1}"
  local AWS_SECRET_KEY="${2}"

  local sctmgr_key_query="SecretList[?contains(Name, "'`'"${AWS_SECRET_KEY}"'`'")].ARN"
  # echo "query: ${sctmgr_key_query}"
  sctmgr_key_exists=$(aws secretsmanager list-secrets --query "${sctmgr_key_query}" --output text 2>&1)
  sctmgr_key_exists_ret_code=$?
  if [[ $sctmgr_key_exists_ret_code -ne 0 ]];
  then
    echo "Failed to search for key ${AWS_SECRET_KEY} in AWS Secret manager with error code ${sctmgr_key_exists_ret_code}."
    echo "${sctmgr_key_exists}"
    return -2
  fi
  if [[ "${sctmgr_key_exists}" == "" ]];
  then
    return 1
  fi
  return 0
}

function AWSStoreKey {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ];
  then
    echo 'AWSStoreKey <Scope> <Key name> <Key Value> [<Value type: [F|f]ile*|[S|s]tring>] [<Key Description>]'
    return -1
  fi
  local AWS_SECRET_SCOPE="${1}"
  local AWS_SECRET_KEY="${2}"
  local AWS_SECRET_VALUE="${3}" 
  local AWS_SECRET_VALUE_TYPE="${4:-F}"
  local AWS_SECRET_KEY_DESCRIPTION="${5:-Key}"

  case "${AWS_SECRET_VALUE_TYPE}" in 

    String|string|s|S)
      local create_status
      create_status=$(aws secretsmanager create-secret --name "${AWS_SECRET_KEY}" --description "${AWS_SECRET_KEY_DESCRIPTION}" --secret-string "${AWS_SECRET_VALUE}" 2>&1)
      local create_ret_code=$?
      if [[ ! $create_ret_code == 0 ]];
      then
        if [[ $create_ret_code == 254 ]];
        then
          echo "AWSStoreKey: Key ${AWS_SECRET_KEY} already exists; adding value as a new secret..."
          local add_secret_status
          add_secret_status=$(aws secretsmanager put-secret-value --secret-id "${AWS_SECRET_KEY}" --secret-string "${AWS_SECRET_VALUE}" 2>&1)
          local add_secret_ret_code=$?
          if [[ ! $add_secret_ret_code == 0 ]];
          then
            echo "AWSStoreKey: Failed to add new secret to key ${AWS_SECRET_KEY} due to error ${add_secret_ret_code}"
            echo "${add_secret_status}"
            return -2
          fi
          echo "AWSStoreKey: Added new secret to key ${AWS_SECRET_KEY}"
        else
          echo "AWSStoreKey: Failed to create key ${AWS_SECRET_KEY} in secret manager due to error ${create_ret_code}."
          echo "${create_status}"
        fi
      else
        echo "AWSStoreKey: Created key ${AWS_SECRET_KEY} in secret manager"
      fi    
      ;;

    File|file|f|F|*)
      if [ ! -f "${AWS_SECRET_VALUE}" ];
      then
        echo "AWSStoreKey: the file ${AWS_SECRET_VALUE} for key ${AWS_SECRET_KEY} does not exist."
        return -3
      fi
      local create_status
      create_status=$(aws secretsmanager create-secret --name "${AWS_SECRET_KEY}" --description "${AWS_SECRET_KEY_DESCRIPTION}" --secret-binary "fileb://${AWS_SECRET_VALUE}" 2>&1)
      local create_ret_code=$?
      if [[ ! $create_ret_code == 0 ]];
      then
        if [[ $create_ret_code == 254 ]];
        then
          echo "AWSStoreKey: Key ${AWS_SECRET_KEY} already exists; adding file as a new secret..."
          local add_secret_status
          add_secret_status=$(aws secretsmanager put-secret-value --secret-id "${AWS_SECRET_KEY}" --secret-binary "fileb://${AWS_SECRET_VALUE}" 2>&1)
          local add_secret_ret_code=$?
          if [[ ! $add_secret_ret_code == 0 ]];
          then
            echo "AWSStoreKey: Failed to add new secret file to key ${AWS_SECRET_KEY} due to error ${add_secret_ret_code}"
            echo "${add_secret_status}"
            return -4
          fi
          echo "AWSStoreKey: Added new file to key ${AWS_SECRET_KEY}"
        else
          echo "AWSStoreKey: Failed to add file to key ${AWS_SECRET_KEY} in secret manager due to error ${create_ret_code}."
          echo "${create_status}"
        fi
      else
        echo "AWSStoreKey: Created key ${AWS_SECRET_KEY} in secret manager using file"
      fi
      ;;

  esac
}

function AWSGetKey {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ];
  then
    echo 'AWSGetKey <Scope> <Key name> [<Value type: [F|f]ile*|[S|s]tring>] [<File Location>] [<Key Description>]'
    return -1
  fi
  local AWS_SECRET_SCOPE="${1}"
  local AWS_SECRET_KEY="${2}"
  local AWS_SECRET_VALUE_TYPE="${4:-F}"
  local AWS_SECRET_VALUE="${3}" 
  local AWS_SECRET_KEY_DESCRIPTION="${5:-Key}"

  case "${AWS_SECRET_VALUE_TYPE}" in 
  
    String|string|s|S)
      local key_extract_status
      key_extract_status=$(aws secretsmanager get-secret-value --secret-id "${AWS_SECRET_KEY}" --query "SecretString" --output text  2>&1)
      local key_extract_ret_code=$?
      if [[ $key_extract_ret_code -ne 0 ]];
      then
        echo "Failed to download key ${AWS_SECRET_KEY} from secret manager due to error ${key_extract_ret_code}"
        echo "${key_extract_status}"
        return -2
       fi
       ;;
     
    File|file|f|F|*)
      local key_extract_status
      key_extract_status=$(aws secretsmanager get-secret-value --secret-id "${AWS_SECRET_KEY}" --query "SecretBinary" --output text > "${AWS_SECRET_VALUE}" 2>&1)
      local key_extract_ret_code=$?
      if [[ $key_extract_ret_code -ne 0 ]];
      then
        echo "Failed to download key ${AWS_SECRET_KEY} from secret manager due to error ${key_extract_ret_code}"
        cat "${AWS_SECRET_VALUE}"
        rm "${AWS_SECRET_VALUE}"
      fi
      ;;
  esac  
}
