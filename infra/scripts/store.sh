
SCRIPT_DEFAULT_HOME=$(cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}" )" &> /dev/null && pwd)
STORE_DEFAULT_HOME=$(pwd)

. "${SCRIPT_DEFAULT_HOME}"/basic.sh

function StoreKey {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ];
  then
    echo "StoreKey <Scope> <Store type: AWS|GCP> <Key name> <Key Value> [<Value type: [F|f]ile*|[S|s]tring>]" 
    return -1
  fi
  local STORE_SCOPE="${1}"
  local STORE_TYPE="${2}"
  local STORE_KEY="${3}"
  local STORE_VALUE="${4}" 
  local STORE_VALUE_TYPE="${5:-F}"
  
  case "${STORE_TYPE}" in
    
    AWS)
      . "${SCRIPT_DEFAULT_HOME}"/aws.sh
      IsAvailable f AWSStoreKey "AWSStoreKey function"
      local awsStoreKey_status
      awsStoreKey_status=$(AWSStoreKey "${STORE_SCOPE}" "${STORE_KEY}" "${STORE_VALUE}" "${STORE_VALUE_TYPE}")
      local awsStoreKey_ret_code=$?
      if [ $awsStoreKey_ret_code -ne 0 ];
      then
        echo "Failed to store key in AWS due to error ${awsStoreKey_ret_code}"
        echo "${awsStoreKey_status}"
        return -2
      fi
      ;;

    *)
      echo "StoreKey: Only AWS Store type is currently supported."
      exit
      ;; 
  esac
}

function StoreKeyExists {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ];
  then
    echo "StoreKey <Scope> <Store type: AWS|GCP> <Key name>" 
    return -1
  fi
  local STORE_SCOPE="${1}"
  local STORE_TYPE="${2}"
  local STORE_KEY="${3}"
  case "${STORE_TYPE}" in
    
    AWS)
      . "${SCRIPT_DEFAULT_HOME}"/aws.sh
      IsAvailable f AWSContainsKey "AWSContainsKey function"
      AWSContainsKey "${STORE_SCOPE}" "${STORE_KEY}"
      local awsContainsKey_ret_code=$?
      if [ $awsContainsKey_ret_code -eq 0 ];
      then
        return 0
      fi
      if [ $awsContainsKey_ret_code -eq 1 ];
      then
        return 1
      else
        return -2
      fi
      ;;

    *)
      echo "StoreKeyExists: Only AWS Store type is currently supported."
      exit
      ;; 
  esac

}

function GetStoredKey {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ];
  then
    echo "StoreKey <Scope> <Store type: AWS|GCP> <Key name> <Key Value> [<Value type: [F|f]ile*|[S|s]tring>]" 
    return -1
  fi
  local STORE_SCOPE="${1}"
  local STORE_TYPE="${2}"
  local STORE_KEY="${3}"
  local STORE_VALUE="${4}" 
  local STORE_VALUE_TYPE="${5:-F}"
  
  case "${STORE_TYPE}" in
    
    AWS)
      . "${SCRIPT_DEFAULT_HOME}"/aws.sh
      IsAvailable f AWSGetKey "AWSGetKey function"
      awsGetKeyValue=$(AWSGetKey "${STORE_SCOPE}" "${STORE_KEY}" "${STORE_VALUE}" "${STORE_VALUE_TYPE}")
      local awsGetKey_ret_code=$?
      if [ $awsGetKey_ret_code -ne 0 ];
      then
        echo "Failed to read key from AWS due to error ${awsGetKey_ret_code}"
        echo "${awsGetKeyValue}"
        return -2
      else
        echo "${awsGetKeyValue}"
      fi
      ;;

    *)
      echo "GetKey: Only AWS Store type is currently supported."
      exit
      ;; 
  esac
}

