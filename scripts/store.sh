
SCRIPT_DEFAULT_HOME=$(cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}" )" &> /dev/null && pwd)
# STORE_DEFAULT_HOME=$(pwd)

. "${SCRIPT_DEFAULT_HOME}"/basic.sh

function StoreKey {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ];
  then
    echo "StoreKey <Scope> <Store type: AWS|GCP> <Key name> <Key Value> [<Value type: [F|f]ile*|[S|s]tring>] [<Return: Exit*|Return>] [Exit code]"
    ReturnOrExit "${6:-Exit}" "${7:-1}" "1"; return $?
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
        ReturnOrExit "${6:-Exit}" "${7:-1}" "2"; return $?
      fi
      ;;

    GCP)
      . "${SCRIPT_DEFAULT_HOME}"/gcpSecret.sh
      IsAvailable f GCPSecretCreate "GCPSecretCreate function"
      local gcpStoreKey_status
      gcpStoreKey_status=$(GCPSecretCreate "${STORE_SCOPE}" "${STORE_KEY}" "${STORE_VALUE}" "${STORE_VALUE_TYPE}")
      local gcpStoreKey_ret_code=$?
      if [ $gcpStoreKey_ret_code -ne 0 ];
      then
        echo "Failed to store key ${STORE_KEY} in GCP due to error ${gcpStoreKey_ret_code}"
        echo "${gcpStoreKey_status}"
        ReturnOrExit "${6:-Exit}" "${7:-1}" "4"; return $?
      fi
      ;;

    *)
      echo "StoreKey: Only AWS and GCP Store type is currently supported."
      ReturnOrExit "${6:-Exit}" "${7:-1}" "3"; return $?
      ;;
  esac
}

function StoreKeyExists {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ];
  then
    echo "StoreKey <Scope> <Store type: AWS|GCP> <Key name> [<Return: Exit*|Return>] [Exit code]"
    ReturnOrExit "${4:-Exit}" "${5:-1}" "3"; return $?
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
        ReturnOrExit "${4:-Exit}" "${5:-1}" "2"; return $?
      fi
      ;;

    GCP)
      . "${SCRIPT_DEFAULT_HOME}"/gcp.sh
      IsAvailable f GCPResourceExists "GCPResourceExists function"
      GCPResourceExists "${STORE_SCOPE}" 'secrets' "${STORE_KEY}" 'r'
      local gcpContainsKey_ret_code=$?
      if [ $gcpContainsKey_ret_code -eq 0 ];
      then
        return 0
      fi
      if [ $gcpContainsKey_ret_code -eq 1 ];
      then
        return 1
      else
        ReturnOrExit "${4:-Exit}" "${5:-1}" "2"; return $?
      fi
      ;;

    *)
      echo "StoreKeyExists: Only AWS and GCP Store type is currently supported."
      ReturnOrExit "${4:-Exit}" "${5:-1}" "4"; return $?
      ;;
  esac
}

function GetStoredKey {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ];
  then
    echo "GetStoredKey <Scope> <Store type: AWS|GCP> <Key name> <Key Value> [<Value type: [F|f]ile*|[S|s]tring>] [<Return: Exit*|Return>] [Exit code]"
    ReturnOrExit "${6:-Exit}" "${7:-1}" "1"; return $?
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
        echo "GetStoredKey: Failed to read key from AWS due to error ${awsGetKey_ret_code}"
        echo "${awsGetKeyValue}"
        ReturnOrExit "${6:-Exit}" "${7:-1}" "2"; return $?
      else
        echo "${awsGetKeyValue}"
      fi
      ;;

    GCP)
      . "${SCRIPT_DEFAULT_HOME}"/gcpSecret.sh
      IsAvailable f GCPGetSecret "GCPGetSecret function"
      gcpGetKeyValue=$(GCPGetSecret "${STORE_SCOPE}" "${STORE_KEY}" "${STORE_VALUE}" "${STORE_VALUE_TYPE}")
      local gcpGetKey_ret_code=$?
      if [ $gcpGetKey_ret_code -ne 0 ];
      then
        echo "GetStoredKey: Failed to read key from GCP due to error ${gcpGetKey_ret_code}"
        echo "${gcpGetKeyValue}"
        ReturnOrExit "${6:-Exit}" "${7:-1}" "4"; return $?
      else
        echo "${gcpGetKeyValue}"
      fi
      ;;

    *)
      echo "GetStoredKey: Only AWS and GCP Store type is currently supported."
      ReturnOrExit "${6:-Exit}" "${7:-1}" "3"; return $?
      ;;
  esac
}

function DeleteStoreKey {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ];
  then
    echo "DeleteStoreKey <Scope> <Store type: AWS|GCP> <Key name>  [<Return: Exit*|Return>] [Exit code]"
    ReturnOrExit "${4:-Exit}" "${5:-1}" "1"; return $?
  fi
  local STORE_SCOPE="${1}"
  local STORE_TYPE="${2}"
  local STORE_KEY="${3}"

  case "${STORE_TYPE}" in

    AWS)
      . "${SCRIPT_DEFAULT_HOME}"/aws.sh
      IsAvailable f AWSDeleteResource "AWSDeleteResource function"
      local awsDeleteKey_status
      awsDeleteKey_status=$(AWSDeleteResource "${STORE_SCOPE}" 'SecretVault' "${STORE_KEY}")
      local awsDeleteKey_ret_code=$?
      if [ $awsDeleteKey_ret_code -ne 0 ];
      then
        echo "Failed to delete key ${STORE_KEY} from AWS due to error ${awsDeleteKey_ret_code}"
        echo "${awsDeleteKey_status}"
        ReturnOrExit "${4:-Exit}" "${5:-1}" "2"; return $?
      fi
      ;;

    *)
      echo "DeleteStoreKey: Only AWS Store type is currently supported."
      ReturnOrExit "${4:-Exit}" "${5:-1}" "3"; return $?
      ;;
  esac
}

function StoreFile {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ];
  then
    echo "StoreFile <Scope> <Store type: AWS|GCP> <Source file path> <destination file location> [<Return: Exit*|Return>] [Exit code]"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "1"; return $?
  fi
  local STORE_SCOPE="${1}"
  local STORE_TYPE="${2}"
  local STORE_FILE_SRC="${3}"
  local STORE_FILE_DEST="${4}"

  case "${STORE_TYPE}" in

    AWS)
      . "${SCRIPT_DEFAULT_HOME}"/aws.sh
      IsAvailable f AWSStoreFile "AWSStoreFile function"
      local awsStoreFile_status
      awsStoreFile_status=$(AWSStoreFile "${STORE_SCOPE}" "${STORE_FILE_SRC}" "${STORE_FILE_DEST}")
      local awsStoreFile_ret_code=$?
      if [ $awsStoreFile_ret_code -ne 0 ];
      then
        echo "Failed to store file in AWS due to error ${awsStoreFile_ret_code}"
        echo "${awsStoreFile_status}"
        ReturnOrExit "${5:-Exit}" "${6:-1}" "2"; return $?
      fi
      ;;

    GCP)
      . "${SCRIPT_DEFAULT_HOME}"/gcpFileStore.sh
      IsAvailable f GCPStoreFile "GCPStoreFile function"
      local gcpStoreFile_status
      gcpStoreFile_status=$(GCPStoreFile "${STORE_SCOPE}" "${STORE_FILE_SRC}" "${STORE_FILE_DEST}")
      local gcpStoreFile_ret_code=$?
      if [ $gcpStoreFile_ret_code -ne 0 ]; then
        echo "Failed to store file in GCP due to error ${gcpStoreFile_ret_code}"
        echo "${gcpStoreFile_status}"
        ReturnOrExit "${5:-Exit}" "${6:-1}" "4"; return $?
      fi
      ;;

    *)
      echo "StoreFile: Only AWS Store type is currently supported."
      ReturnOrExit "${5:-Exit}" "${6:-1}" "3"; return $?
      ;;
  esac
}

function GetStoredFile {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ];
  then
    echo "GetStoredFile <Scope> <Store type: AWS|GCP> <source file> <destination path> [<Return: Exit*|Return>] [Exit code]"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "1"; return $?
  fi
  local STORE_SCOPE="${1}"
  local STORE_TYPE="${2}"
  local STORE_FILE_NAME="${3}"
  local STORE_FILE_PATH="${4}"

  case "${STORE_TYPE}" in

    AWS)
      . "${SCRIPT_DEFAULT_HOME}"/aws.sh
      IsAvailable f AWSGetFile "AWSGetFile function"
      awsGetFileValue=$(AWSGetFile "${STORE_SCOPE}" "${STORE_FILE_NAME}" "${STORE_FILE_PATH}")
      local awsGetFile_ret_code=$?
      if [ $awsGetFile_ret_code -ne 0 ];
      then
        echo "GetStoredFile: Failed to read file from AWS due to error ${awsGetKey_ret_code}"
        echo "${awsGetFileValue}"
        ReturnOrExit "${5:-Exit}" "${6:-1}" "2"; return $?
      else
        echo "${awsGetFileValue}"
      fi
      ;;

    GCP)
      . "${SCRIPT_DEFAULT_HOME}"/gcpFileStore.sh
      IsAvailable f GCPGetFile "GCPGetFile function"
      gcpGetFileValue=$(GCPGetFile "${STORE_SCOPE}" "${STORE_FILE_NAME}" "${STORE_FILE_PATH}")
      local gcpGetFile_ret_code=$?
      if [ $gcpGetFile_ret_code -ne 0 ];
      then
        echo "GetStoredFile: Failed to read file from GCP due to error ${gcpGetFile_ret_code}"
        echo "${gcpGetFileValue}"
        ReturnOrExit "${5:-Exit}" "${6:-1}" "4"; return $?
      else
        echo "${gcpGetFileValue}"
      fi
      ;;

    *)
      echo "GetStoredFile: Only AWS Store type is currently supported."
      ReturnOrExit "${5:-Exit}" "${6:-1}" "3"; return $?
      ;;
  esac
}
