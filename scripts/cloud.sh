SCRIPT_DEFAULT_HOME=$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd)
INFRA_DEFAULT_HOME=$(pwd)

. "${SCRIPT_DEFAULT_HOME}"/basic.sh

function CloudInit {
  if [ "${1}" == "" ] || [ "${2}" == "" ]; then
    echo 'CloudInit <Scope> <Cloud type: AWS|GCP> [<Cloud specific Auth Type: e.g. env*|profile>] [<cloud specific auth data e.g. profile name>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${5:-Exit}" "${6:-1}" "1"
    return $?
  fi
  local CLOUD_SCOPE="${1}"
  local CLOUD_TYPE="${2}"
  local CLOUD_AUTH_TYPE="${3}"
  local CLOUD_AUTH_DATA="${4}"
  echo "Initializing ${CLOUD_TYPE} cloud environment for ${CLOUD_SCOPE}..."
  case "${CLOUD_TYPE}" in

  'AWS')
    . "${SCRIPT_DEFAULT_HOME}/aws.sh"
    IsAvailable f AWSInit "AWS Init (AWSInit) function"
    AWSInit "${CLOUD_SCOPE}" '' "${CLOUD_AUTH_TYPE}" "${CLOUD_AUTH_DATA}"
    local cldInit_ret_code=$?
    if [ $cldInit_ret_code -ne 0 ]; then
      echo "CloudInit: Failed to initialize connection to cloud ${CLOUD_TYPE} due to ${cldInit_ret_code}"
      ReturnOrExit "${5:-Exit}" "${6:-1}" "2"
      return $?
    fi
    ;;

  *)
    echo "CloudInit: Only AWS cloud type is currently supported."
    ReturnOrExit "${5:-Exit}" "${6:-1}" "3"
    return $?
    ;;
  esac
  echo "Initialized ${CLOUD_TYPE} cloud environment for ${CLOUD_SCOPE}."
}

function CloudGetResource {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${4}" == "" ] || [ "${4}" == "" ]; then
    echo 'CloudGetResource <Scope> <Cloud type: AWS|GCP> <Resource Type: e.g. FileStore|Vault> <name or partial name> [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${5:-Exit}" "${6:-1}" "1"
    return $?
  fi
  local CLOUD_SCOPE="${1}"
  local CLOUD_TYPE="${2}"
  local CLOUD_RES_TYPE="${3}"
  local CLOUD_RES_NAME="${4}"
  case "${CLOUD_TYPE}" in

  'AWS')
    . "${SCRIPT_DEFAULT_HOME}/aws.sh"
    IsAvailable f AWSGetResource "AWSGetResource function"
    local cldGetRes_status
    cldGetRes_status=$(AWSGetResource "${CLOUD_SCOPE}" "${CLOUD_RES_TYPE}" "${CLOUD_RES_NAME}")
    local cldGetRes_ret_code=$?
    if [ $cldGetRes_ret_code -ne 0 ]; then
      echo "CloudGetResource: Failed to get resource ${CLOUD_RES_NAME} of type ${CLOUD_RES_TYPE} from ${CLOUD_TYPE} due to ${cldGetRes_ret_code}"
      echo "${cldGetRes_status}"
      ReturnOrExit "${5:-Exit}" "${6:-1}" "2"
      return $?
    else
      echo "${cldGetRes_status}"
    fi
    ;;

  *)
    echo "CloudGetResource: Only AWS cloud type is currently supported."
    ReturnOrExit "${5:-Exit}" "${6:-1}" "3"
    return $?
    ;;
  esac
}