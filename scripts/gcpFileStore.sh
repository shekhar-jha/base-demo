SCRIPT_DEFAULT_HOME=$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd)
GCP_DEFAULT_HOME=$(pwd)
GCP_DEFAULT_REGION="${CLOUD_DEFAULT_REGION:us-central1-a}"

. "${SCRIPT_DEFAULT_HOME}"/basic.sh
. "${SCRIPT_DEFAULT_HOME}"/gcp.sh

function GCPStoreFile {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ]; then
    echo 'GCPStoreFile <Scope> <Source file Path> <target file name> [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${4:-Exit}" "${5:-1}" "1"
    return $?
  fi
  local GCP_GCS_SCOPE="${1}"
  local GCP_GCS_FILE_PATH="${2}"
  local GCP_GCS_FILE_NAME="${3}"
  if [[ ! -f "${GCP_GCS_FILE_PATH}" ]]; then
    echo "GCPStoreFile: Failed to store file ${GCP_GCS_FILE_NAME} since file path ${GCP_GCS_FILE_PATH} is invalid"
    ReturnOrExit "${4:-Exit}" "${5:-1}" "2"
    return $?
  fi
  local upload_status
  upload_status=$(gsutil cp "${GCP_GCS_FILE_PATH}" "gs://${GCP_GCS_FILE_NAME}" 2>&1)
  local upload_ret_code=$?
  if [[ $upload_ret_code -ne 0 ]]; then
    echo "GCPStoreFile: Failed to store file ${GCP_GCS_FILE_PATH} to ${GCP_GCS_FILE_NAME} due to error ${upload_ret_code}"
    echo "${upload_status}"
    ReturnOrExit "${4:-Exit}" "${5:-1}" "3"
    return $?
  else
    echo "GCPStoreFile: Stored file to ${GCP_GCS_FILE_NAME}"
  fi
}

function GCPGetFile {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ]; then
    echo 'GCPGetFile <Scope> <File name> <File Path> [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${4:-Exit}" "${5:-1}" "1"
    return $?
  fi
  local GCP_GCS_SCOPE="${1}"
  local GCP_GCS_FILE_NAME="${2}"
  local GCP_GCS_FILE_PATH="${3}"
  local download_status
  download_status=$(gsutil cp "${GCP_GCS_FILE_NAME}" "${GCP_GCS_FILE_PATH}" 2>&1)
  local download_ret_code=$?
  if [[ download_ret_code -ne 0 ]]; then
    echo "GCPGetFile: Failed to retrieve file ${GCP_GCS_FILE_NAME} to ${GCP_GCS_FILE_PATH} due to error ${download_ret_code}"
    echo "${download_status}"
    ReturnOrExit "${4:-Exit}" "${5:-1}" "2"
    return $?
  else
    echo "GCPGetFile: Downloaded file to ${GCP_GCS_FILE_PATH}"
  fi
}
