SCRIPT_DEFAULT_HOME=$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd)
SRC_DEFAULT_HOME=$(pwd)
GCP_DEFAULT_REGION="${CLOUD_DEFAULT_REGION:us-central1-a}"

. "${SCRIPT_DEFAULT_HOME}"/basic.sh
. "${SCRIPT_DEFAULT_HOME}"/gcp.sh

function GCPSourceRepoHome {
  if [ "${1}" == "" ] || [ "${2}" == "" ]; then
    echo 'GCPSourceRepoHome <Scope> <Repo name> [<Home: '" ${SRC_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${4:-Exit}" "${5:-1}" "1"
    return $?
  fi
  local SRC_SCOPE="${1}"
  local SRC_NAME="${2}"
  local SRC_HOME="${3:-$SRC_DEFAULT_HOME}"
  local SRC_BASE="${SRC_HOME}/${SRC_SCOPE}_gcpcode_${SRC_NAME}"
  if [ ! -d "${SRC_BASE}" ]; then
    mkdir -p "${SRC_BASE}"
  fi
  echo "${SRC_BASE}"
  return 0
}

function GCPSourceRepoInit {
  if [[ "${1}" == "" ]] || [[ "${2}" == "" ]]; then
    echo 'GCPSourceRepoInit <Scope> <Repo name> [<Home: '" ${SRC_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${4:-Exit}" "${5:-1}" "1"
    return $?
  fi
  local SRC_SCOPE="${1}"
  local SRC_NAME="${2}"
  local SRC_HOME="${3:-$CMT_DEFAULT_HOME}"
  local SRC_BASE
  SRC_BASE=$(GCPSourceRepoHome "${SRC_SCOPE}" "${SRC_NAME}" "${SRC_HOME}")
  if [[ -d ${SRC_BASE}/.git ]]; then
    echo "GCPSourceRepoInit: Removing existing repository from ${SRC_BASE}"
    rm -rf ${SRC_BASE}
  fi
  local clone_status
  echo "GCPSourceRepoInit: Cloning repository..."
  clone_status=$(gcloud source repos clone ${SRC_NAME} ${SRC_BASE} 2>&1)
  local clone_ret_val=$?
  if [ $clone_ret_val -ne 0 ]; then
    echo "GCPSourceRepoInit: Failed to clone git repo ${SRC_NAME} with error ${clone_ret_val}. SRC_BASE=${SRC_BASE}"
    echo "${clone_status}"
    ReturnOrExit "${4:-Exit}" "${5:-1}" "2"
    return $?
  fi
  echo "GCPSourceRepoPush: Adding files...."
  git "--git-dir=${SRC_BASE}/.git" "--work-tree=${SRC_BASE}/" fetch
}

function GCPSourceRepoCopy {
  if [[ "${1}" == "" ]] || [[ "${2}" == "" ]] || [[ "${3}" == "" ]]; then
    echo 'GCPSourceRepoCopy <Scope> <Repo name> <Source code path> [<Home: '" ${SRC_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${5:-Exit}" "${6:-1}" "1"
    return $?
  fi
  local SRC_SCOPE="${1}"
  local SRC_NAME="${2}"
  local SRC_SRC="${3}"
  local SRC_HOME="${4:-$SRC_DEFAULT_HOME}"
  local SRC_BASE
  SRC_BASE=$(GCPSourceRepoHome "${SRC_SCOPE}" "${SRC_NAME}" "${SRC_HOME}")
  if [[ ! -d ${SRC_BASE} ]]; then
    echo "GCPSourceRepoCopy: Failed to copy the updates to repo ${SRC_NAME} due to missing repository. Please initialize repo before copy. SRC_BASE=${SRC_BASE}"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "2"
    return $?
  fi
  if [[ ! -d ${SRC_SRC} ]]; then
    echo "GCPSourceRepoCopy: Failed to copy the updates to repo ${SRC_NAME} since source directory ${SRC_SRC} does not exist. SRC_BASE=${SRC_BASE}"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "3"
    return $?
  fi
  echo "GCPSourceRepoCopy: Copying files from ${SRC_SRC} to ${SRC_BASE}"
  cp -R "${SRC_SRC}" "${SRC_BASE}"
  local copy_ret_val=$?
  if [[ $copy_ret_val -ne 0 ]]; then
    echo "GCPSourceRepoCopy: Failed to copy updates to git repo ${SRC_NAME} with error ${copy_ret_val}. SRC_BASE=${SRC_BASE}"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "4"
    return $?
  fi
}

function GCPSourceRepoPush {
  if [[ "${1}" == "" ]] || [[ "${2}" == "" ]]; then
    echo 'GCPSourceRepoPush <Scope> <Repo name> [<Commit message>] [<Home: '" ${SRC_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${5:-Exit}" "${6:-1}" "1"
    return $?
  fi
  local SRC_SCOPE="${1}"
  local SRC_NAME="${2}"
  local SRC_MSG="${3:-Change made}"
  local SRC_HOME="${4:-$SRC_DEFAULT_HOME}"
  local SRC_BASE
  SRC_BASE=$(GCPSourceRepoHome "${SRC_SCOPE}" "${SRC_NAME}" "${SRC_HOME}")
  if [[ ! -d ${SRC_BASE}/.git ]]; then
    echo "GCPSourceRepoPush: Failed to commit updates to repo ${SRC_NAME} since the location is not initialized. Please initialize repo before copy. SRC_BASE=${SRC_BASE}"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "2"
    return $?
  fi
  echo "GCPSourceRepoPush: Adding files...."
  git "--git-dir=${SRC_BASE}/.git" "--work-tree=${SRC_BASE}/" add .
  local copy_ret_val=$?
  if [[ $copy_ret_val -ne 0 ]]; then
    echo "GCPSourceRepoPush: Failed to add files for commit to ${SRC_NAME} with error ${copy_ret_val}. SRC_BASE=${SRC_BASE}"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "3"
    return $?
  fi
  echo "GCPSourceRepoPush: Committing changes...."
  git "--git-dir=${SRC_BASE}/.git" "--work-tree=${SRC_BASE}/" commit -m "${SRC_MSG}"
  copy_ret_val=$?
  if [[ $copy_ret_val -ne 0 ]]; then
    echo "GCPSourceRepoPush: Failed to commit to ${SRC_NAME} with error ${copy_ret_val}. SRC_BASE=${SRC_BASE}"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "4"
    return $?
  fi
  echo "GCPSourceRepoPush: Pushing updates...."
  git "--git-dir=${SRC_BASE}/.git" "--work-tree=${SRC_BASE}/" push origin main
  copy_ret_val=$?
  if [[ $copy_ret_val -ne 0 ]]; then
    echo "GCPSourceRepoPush: Failed to push update to ${SRC_NAME} with error ${copy_ret_val}. SRC_BASE=${SRC_BASE}"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "5"
    return $?
  fi
}

function GCPSourceRepoCleanup {
  if [[ "${1}" == "" ]] || [[ "${2}" == "" ]]; then
    echo 'GCPSourceRepoCleanup <Scope> <Repo name> [<Home: '" ${SRC_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${4:-Exit}" "${5:-1}" "1"
    return $?
  fi
  local SRC_SCOPE="${1}"
  local SRC_NAME="${2}"
  local SRC_HOME="${3:-$SRC_DEFAULT_HOME}"
  local SRC_BASE
  SRC_BASE=$(GCPSourceRepoHome "${SRC_SCOPE}" "${SRC_NAME}" "${SRC_HOME}")
  echo "GCPSourceRepoCleanup: Deleting the local copy of repo at ${SRC_BASE}...."
  if [[ -d ${SRC_BASE}/.git ]]; then
    rm -rf "${SRC_BASE}"
    delete_ret_val=$?
    if [[ $delete_ret_val -ne 0 ]]; then
      echo "GCPSourceRepoCleanup: Failed to delete the local copy of repo ${SRC_NAME} due to error code ${delete_ret_val}. SRC_BASE=${SRC_BASE}"
      ReturnOrExit "${4:-Exit}" "${5:-1}" "3"
      return $?
    fi
  else
    echo "GCPSourceRepoCleanup: Failed to delete the local copy of repo ${SRC_NAME} since the given location does not contain git repository. Please check the location. SRC_BASE=${SRC_BASE}"
    return 4
  fi
}
