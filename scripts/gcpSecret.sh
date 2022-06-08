SCRIPT_DEFAULT_HOME=$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd)
GCP_DEFAULT_HOME=$(pwd)
GCP_DEFAULT_REGION="${CLOUD_DEFAULT_REGION:us-central1-a}"

. "${SCRIPT_DEFAULT_HOME}"/basic.sh
. "${SCRIPT_DEFAULT_HOME}"/gcp.sh

function GCPSecretName {
  if [[ "${1}" == "" ]] || [[ "${2}" == "" ]]; then
    echo "GCPSecretName <Scope> <key name> [<Return: Exit*|Return>] [Exit code]"
    ReturnOrExit "${3:-Exit}" "${4:-1}" "1"
    return $?
  fi
  local GCP_INIT_SCOPE="${1}"
  local GCP_KEY_NAME="${2}"
  echo "${GCP_KEY_NAME}"
}

function GCPSecretCreate {
  if [[ "${1}" == "" ]] || [[ "${2}" == "" ]] || [[ "${3}" == "" ]]; then
    echo "GCPSecretCreate <Scope> <Key name> <Key Value> [<Value type: [F|f]ile*|[S|s]tring>] [<Return: Exit*|Return>] [Exit code]"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "1"
    return $?
  fi
  local GCP_INIT_SCOPE="${1}"
  local GCP_KEY_NAME="${2}"
  local GCP_KEY_VALUE="${3}"
  local GCP_VALUE_TYPE="${4:-f}"
  local SECRET_NAME
  SECRET_NAME="$(GCPSecretName $GCP_INIT_SCOPE $GCP_KEY_NAME)"
  case "${GCP_VALUE_TYPE}" in
  F | f | File | file)
    if [[ ! -f "${GCP_KEY_VALUE}" ]]; then
      echo "GCPSecretCreate: Failed to create secret since the key file ${GCP_KEY_VALUE} is missing"
      ReturnOrExit "${5:-Exit}" "${6:-1}" "2"
      return $?
    fi
    gcloud secrets create "${SECRET_NAME}" "--data-file=${GCP_KEY_VALUE}"
    local create_ret_val=$?
    if [[ $create_ret_val -ne 0 ]]; then
      echo "GCPSecretCreate: Failed to create secret ${SECRET_NAME} using file with error code ${create_ret_val}"
      ReturnOrExit "${5:-Exit}" "${6:-1}" "3"
      return $?
    else
      echo "GCPSecretCreate: Created secret ${SECRET_NAME}"
    fi
    ;;

  s | S | string | String)
    echo "${GCP_KEY_VALUE}" | gcloud secrets create "${SECRET_NAME}" "--data-file=-"
    local create_ret_val=$?
    if [[ $create_ret_val -ne 0 ]]; then
      echo "GCPSecretCreate: Failed to create secret ${SECRET_NAME} using string with error code ${create_ret_val}"
      ReturnOrExit "${5:-Exit}" "${6:-1}" "4"
      return $?
    else
      echo "GCPSecretCreate: Created secret ${SECRET_NAME} using string"
    fi
    ;;

  *)
    echo "GCPSecretCreate: Failed to create secret ${SECRET_NAME} since only string or file value types are supported."
    ReturnOrExit "${5:-Exit}" "${6:-1}" "5"
    return $?
    ;;

  esac
}


function GCPGetSecret {
  if [[ "${1}" == "" ]] || [[ "${2}" == "" ]] || [[ "${3}" == "" ]]; then
    echo "GCPGetSecret <Scope> <Key name> <Key Value> [<Value type: [F|f]ile*|[S|s]tring>] [<Return: Exit*|Return>] [Exit code]"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "1"
    return $?
  fi
  local GCP_INIT_SCOPE="${1}"
  local GCP_KEY_NAME="${2}"
  local GCP_KEY_VALUE="${3}"
  local GCP_VALUE_TYPE="${4:-f}"
  local SECRET_NAME
  SECRET_NAME="$(GCPSecretName $GCP_INIT_SCOPE $GCP_KEY_NAME)"
  case "${GCP_VALUE_TYPE}" in
  F | f | File | file)
    local key_extract_status
    key_extract_status=$(gcloud secrets versions access latest  --secret=${SECRET_NAME} \
            --format='get(payload.data)' | tr '_-' '/+' > "${GCP_KEY_VALUE}" 2>&1)
    local extract_ret_val=$?
    if [[ $extract_ret_val -ne 0 ]]; then
      echo "GCPGetSecret: Failed to get secret ${SECRET_NAME} into file with error code ${extract_ret_val}"
      cat "${GCP_KEY_VALUE}"
      rm "${GCP_KEY_VALUE}"
      ReturnOrExit "${5:-Exit}" "${6:-1}" "2"
      return $?
    fi
    ;;

  s | S | string | String)
    key_extract_status=$(gcloud secrets versions access latest  --secret=${SECRET_NAME} \
            --format='get(payload.data)' | tr '_-' '/+' | base64 -d 2>&1)
    local extract_ret_val=$?
    if [[ $extract_ret_val -ne 0 ]]; then
      echo "GCPGetSecret: Failed to get secret ${SECRET_NAME} into file with error code ${extract_ret_val}"
      echo "${key_extract_status}"
      ReturnOrExit "${5:-Exit}" "${6:-1}" "3"
      return $?
    else
      echo "${key_extract_status}"
    fi
    ;;

  *)
    echo "GCPSecretCreate: Failed to create secret ${SECRET_NAME} since only string or file value types are supported."
    ReturnOrExit "${5:-Exit}" "${6:-1}" "4"
    return $?
    ;;

  esac
}
