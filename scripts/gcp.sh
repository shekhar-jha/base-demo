SCRIPT_DEFAULT_HOME=$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd)
GCP_DEFAULT_HOME=$(pwd)
GCP_DEFAULT_REGION="${CLOUD_DEFAULT_REGION:us-central1-a}"

. "${SCRIPT_DEFAULT_HOME}"/basic.sh

IsAvailable c gcloud "Google Cloud CLI"

function GCPInit {
  if [ "${1}" == "" ]; then
    echo "GCPInit <Scope> [<project id>] [<Authentication type: adc*|service|cred>] [<credential-file-path>] [<service-account-name>] [<password-file-path>] [<Return: Exit*|Return>] [Exit code]"
    ReturnOrExit "${7:-Exit}" "${8:-1}" "1"
    return $?
  fi
  local GCP_INIT_SCOPE="${1}"
  local GCP_PROJECT_ID="${2}"
  local GCP_AUTH_TYPE="${3:-adc}"
  local GCP_CRED_FILE="${4}"
  local GCP_SERVICE_ACCOUNT="${5}"
  local GCP_PWD_FILE="${6}"

  unset GOOGLE_APPLICATION_CREDENTIALS
  unset CLOUDSDK_CORE_ACCOUNT
  unset CLOUDSDK_AUTH_ACCESS_TOKEN_FILE

  case "${GCP_AUTH_TYPE}" in

  "adc")
    if [[ "${GCP_CRED_FILE}" != "" ]]; then
      if [[ -f "${GCP_CRED_FILE}" ]]; then
        echo "GCPInit: Authenticating using application default with client identity file ${GCP_CRED_FILE}..."
        gcloud auth application-default login "--client-id-file=${GCP_CRED_FILE}"
        local auth_ret_val=$?
        if [[ $auth_ret_val -ne 0 ]]; then
          echo "GCPInit: Failed to authenticate using application default credential with error code ${auth_ret_val}"
          ReturnOrExit "${7:-Exit}" "${8:-1}" "3"
          return $?
        fi
      else
        echo "GCPInit: Failed to authenticate using application default since client identity file ${GCP_CRED_FILE} could not be located"
        ReturnOrExit "${7:-Exit}" "${8:-1}" "2"
        return $?
      fi
    else
      echo "GCPInit: Authentication using application default is pre-requisite.."
    fi
    ;;

  service)
    local SERVICE_ACTIVATE_COMMAND="gcloud auth activate-service-account "
    if [[ "${GCP_SERVICE_ACCOUNT}" != "" ]]; then
      SERVICE_ACTIVATE_COMMAND="${SERVICE_ACTIVATE_COMMAND} ${GCP_SERVICE_ACCOUNT}"
    fi
    if [[ ! -f "${GCP_CRED_FILE}" ]]; then
      echo "GCPInit: Authentication using service account failed due to missing key file ${GCP_CRED_FILE}"
      ReturnOrExit "${7:-Exit}" "${8:-1}" "4"
      return $?
    else
      SERVICE_ACTIVATE_COMMAND="${SERVICE_ACTIVATE_COMMAND} "'"'"--key-file=${GCP_CRED_FILE}"'"'" "
    fi
    if [[ "${GCP_PWD_FILE}" != "" ]]; then
      if [[ ! -f "${GCP_PWD_FILE}" ]]; then
        echo "GCPInit: Authentication using service account failed due to missing password file ${GCP_PWD_FILE}"
        ReturnOrExit "${7:-Exit}" "${8:-1}" "5"
        return $?
      else
        SERVICE_ACTIVATE_COMMAND="${SERVICE_ACTIVATE_COMMAND} \"--password-file==${GCP_PWD_FILE}\" "
      fi
    fi
    echo "GCPInit: Authenticating using service account..."
    local auth_res
    auth_res=$($SERVICE_ACTIVATE_COMMAND)
    local auth_ret_val=$?
    if [[ $auth_ret_val -ne 0 ]]; then
      echo "GCPInit: Failed to authenticate using service account with error code ${auth_ret_val}"
      echo "${auth_res}"
      ReturnOrExit "${7:-Exit}" "${8:-1}" "6"
      return $?
    else
      echo "${auth_res}"
    fi
    ;;

  'cred')
    if [[ "${GCP_CRED_FILE}" != "" ]]; then
      if [[ -f "${GCP_CRED_FILE}" ]]; then
        echo "GCPInit: Authenticating using credential file ${GCP_CRED_FILE}..."
        gcloud auth login "--cred-file=${GCP_CRED_FILE}"
        local auth_ret_val=$?
        if [[ $auth_ret_val -ne 0 ]]; then
          echo "GCPInit: Failed to authenticate using credential file ${GCP_CRED_FILE} with error code ${auth_ret_val}"
          ReturnOrExit "${7:-Exit}" "${8:-1}" "7"
          return $?
        fi
      else
        echo "GCPInit: Failed to authenticate using credential file since client identity file ${GCP_CRED_FILE} could not be located"
        ReturnOrExit "${7:-Exit}" "${8:-1}" "8"
        return $?
      fi
    else
      echo "GCPInit: Failed to authenticate using credential file since no credential file was provided.."
      ReturnOrExit "${7:-Exit}" "${8:-1}" "9"
      return $?
    fi
    ;;

  *)
    echo "GCPInit: Invalid authentication type ${GCP_AUTH_TYPE}. Only adc*|service|cred are supported."
    ReturnOrExit "${7:-Exit}" "${8:-1}" "10"
    return $?
    ;;

  esac
  local active_identity
  active_identity=$(gcloud auth list --filter=status=Active --format="value(account)")
  local active_id_sts=$?
  if [ $active_id_sts -ne 0 ]; then
    echo "GCPInit: Failed to identify the active account. Error code: ${active_id_sts}"
    echo "${active_identity}"
    ReturnOrExit "${7:-Exit}" "${8:-1}" "11"
    return $?
  else
    echo "GCPInit: Default active identity is ${active_identity}."
  fi
  if [[ "${GCP_SERVICE_ACCOUNT}" != "" ]]; then
    if [[ "${active_identity}" != "${GCP_SERVICE_ACCOUNT}" ]]; then
      echo "GCPInit: Default active identity ${active_identity} does not match given account ${GCP_SERVICE_ACCOUNT}"
      local matching_account
      matching_account=$(gcloud auth list --filter="-status:ACTIVE account:${GCP_SERVICE_ACCOUNT}" --format="value(account)")
      matching_account_ret_val=$?
      if [[ $matching_account_ret_val -ne 0 ]]; then
        echo "GCPInit: Failed to validate if the requested account is already setup with return code ${matching_account_ret_val}"
        echo "${matching_account}"
        ReturnOrExit "${7:-Exit}" "${8:-1}" "12"
        return $?
      else
        if [[ "${matching_account}" != "${GCP_SERVICE_ACCOUNT}" ]]; then
          echo "GCPInit: Requested account ${GCP_SERVICE_ACCOUNT} is not available to activate"
          echo "Output: ${matching_account}"
          ReturnOrExit "${7:-Exit}" "${8:-1}" "13"
          return $?
        else
          echo "GCPInit: Activating account ${GCP_SERVICE_ACCOUNT}"
          export CLOUDSDK_CORE_ACCOUNT="${GCP_SERVICE_ACCOUNT}"
        fi
      fi
    fi
  fi
  if [[ "${GCP_PROJECT_ID}" != "" ]]; then
    echo "GCPInit: Setting default project to ${GCP_PROJECT_ID}"
    export CLOUDSDK_CORE_PROJECT="${GCP_PROJECT_ID}"
  fi
}

function GCPSetConfig {
  if [[ "${1}" == "" ]] || [[ "${2}" == "" ]]; then
    echo "GCPSetConfig <Scope> <Config Name> [<Config Value>] [<Section>] [<Return: Exit*|Return>] [Exit code]'"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "1"
    return $?
  fi
  local GCP_INIT_SCOPE="${1}"
  local GCP_CFG_NAME="${2}"
  local GCP_CFG_VALUE="${3}"
  local GCP_CFG_SECTION="${4}"
  local config_val_status
  local config_cmd="gcloud config "
  if [[ "${GCP_CFG_VALUE}" == "" ]]; then
    config_cmd="${config_cmd} unset "
  else
    config_cmd="${config_cmd} set "
  fi
  if [[ "${GCP_CFG_SECTION}" != "" ]]; then
    config_cmd="${config_cmd} $GCP_CFG_SECTION/$GCP_CFG_NAME"
  else
    config_cmd="${config_cmd} $GCP_CFG_NAME"
  fi
  if [[ "${GCP_CFG_VALUE}" != "" ]]; then
    config_cmd="${config_cmd} ${GCP_CFG_VALUE} --quiet"
  fi
  config_val_status=$($config_cmd)
  local config_ret_code=$?
  if [[ $config_ret_code -ne 0 ]]; then
    echo "GCPSetConfig: Failed to set the configuration $GCP_CFG_SECTION/$GCP_CFG_NAME"
    echo "${config_val_status}"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "2"
    return $?
  else
    echo "${config_val_status}"
  fi
}

function GCPResourceExists {
  if [[ "${1}" == "" ]] || [[ "${2}" == "" ]] || [[ "${3}" == "" ]]; then
    echo "GCPResourceExists <Scope> <resource type: secrets> <resource name> [<Return: Exit*|Return>] [Exit code]"
    ReturnOrExit "${4:-Exit}" "${5:-1}" "2"
    return $?
  fi
  local GCP_INIT_SCOPE="${1}"
  local GCP_RES_TYPE="${2}"
  local GCP_RES_NAME="${3}"
  local query_cmd="gcloud "
  case "${GCP_RES_TYPE}" in

  'secrets')
    query_cmd="${query_cmd} secrets list --filter=name~projects/[0-9]*/secrets/${GCP_RES_NAME} --format=value(name)"
    ;;

  'FileStore')
    IsAvailable c gsutil "Google Cloud Storage CLI"
    query_cmd="gsutil ls -b gs://${GCP_RES_NAME}*"
    ;;

  *)
    echo "GCPResourceExists: ${GCP_RES_TYPE} is not supported. Only secrets is supported as resource type."
    ReturnOrExit "${4:-Exit}" "${5:-1}" "3"
    return $?
    ;;
  esac
  local query_status
  query_status=$($query_cmd)
  local query_ret_val=$?
  if [[ $query_ret_val -ne 0 ]]; then
    echo "GCPResourceExists: Failed to query ${GCP_RES_TYPE} due to return error code ${query_ret_val}."
    echo "${query_status}"
    ReturnOrExit "${4:-Exit}" "${5:-1}" "4"
    return $?
  else
    if [[ "${query_status}" == "" ]]; then
      return 1
    else
      echo "${query_status}"
    fi
  fi
}

function GCPActivate {
  if [[ "${1}" == "" ]]; then
    echo "GCPActivate <Scope> <service: secrets> [<Return: Exit*|Return>] [Exit code]"
    ReturnOrExit "${3:-Exit}" "${4:-1}" "1"
    return $?
  fi
  local GCP_INIT_SCOPE="${1}"
  local GCP_SERVICE="${2}"
  local service_name
  case "${GCP_SERVICE}" in

  'secrets')
    service_name='secretmanager.googleapis.com'
    ;;

  *)
    echo "GCPActivate: ${GCP_SERVICE} is not supported. Only secrets is supported as activation service."
    ReturnOrExit "${3:-Exit}" "${4:-1}" "2"
    return $?
    ;;
  esac
  local service_available
  service_available=$(gcloud services list "--filter=name:${service_name}" "--format=value(name)")
  local available_ret_code=$?
  if [[ $available_ret_code -eq 0 ]]; then
    if [[ "${service_available}" == "" ]]; then
      gcloud services enable "${service_name}"
      local enable_ret_code=$?
      if [[ $enable_ret_code -ne 0 ]]; then
        echo "GCPActivate: Failed to activate ${GCP_SERVICE} api with return error code ${enable_ret_code}"
        ReturnOrExit "${3:-Exit}" "${4:-1}" "3"
        return $?
      else
        echo "GCPActivate: Activated ${GCP_SERVICE} API."
      fi
    else
      echo "GCPActivate: ${GCP_SERVICE} API already activated."
    fi
  else
    echo "GCPActivate: Failed to check if ${GCP_SERVICE} API is already activated with return error code ${available_ret_code}"
    echo "${service_available}"
    ReturnOrExit "${2:-Exit}" "${3:-1}" "2"
    return $?
  fi
}
