SCRIPT_DEFAULT_HOME=$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd)
REPO_DEFAULT_HOME=$(pwd)

. "${SCRIPT_DEFAULT_HOME}"/basic.sh

function CodeRepoInit() {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ]; then
    echo 'CodeRepoInit <Scope> <Code repo type: AWS|Github> <Code Repo name> [<REPO_HOME>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${5:-Exit}" "${6:-1}" "1"
    return $?
  fi
  local CODEREPO_SCOPE="${1}"
  local CODEREPO_TYPE="${2}"
  local CODEREPO_NAME="${3}"
  local CODEREPO_HOME="${4}"
  echo "CodeRepoInit: Initializing repository ${CODEREPO_NAME} of type ${CODEREPO_TYPE} for ${CODEREPO_SCOPE}..."
  local codeRepo_status
    local codeRepo_ret_code
  case "${CODEREPO_TYPE}" in
  'aws' | 'AWS' | 'codecommit' | 'CodeCommit')
    . "${SCRIPT_DEFAULT_HOME}/awsCommit.sh"
    IsAvailable f AWSCommitInit "CodeCommit Init (AWSCommitInit) function"
    codeRepo_status=$(AWSCommitInit "${CODEREPO_SCOPE}" "${CODEREPO_NAME}" "${CODEREPO_HOME}" 'r')
    codeRepo_ret_code=$?
    ;;

  GCP)
    . "${SCRIPT_DEFAULT_HOME}/gcpSrcRepo.sh"
    IsAvailable f GCPSourceRepoInit "GCP Source Repo Initialize (GCPSourceRepoInit) function"
    codeRepo_status=$(GCPSourceRepoInit "${CODEREPO_SCOPE}" "${CODEREPO_NAME}" "${CODEREPO_HOME}" 'r')
    codeRepo_ret_code=$?
    ;;

  *)
    echo "CodeRepoInit: Only AWS Code commit and GCP Source Repo are currently supported."
    ReturnOrExit "${5:-Exit}" "${6:-1}" "3"
    return $?
    ;;

  esac
  if [[ $codeRepo_ret_code -ne 0 ]]; then
    echo "CodeRepoInit: Failed to initialize ${CODEREPO_TYPE} due to error code ${codeRepo_ret_code}"
    echo "${codeRepo_status}"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "2"
    return $?
  else
    echo "${codeRepo_status}"
  fi
  echo "CodeRepoInit: Initialized repository ${CODEREPO_NAME} of type ${CODEREPO_TYPE} for ${CODEREPO_SCOPE}."
}

function CodeRepoUpdate() {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ]; then
    echo 'CodeRepoUpdate <Scope> <Code repo type: AWS|Github> <Repo name> <Source code path> [<REPO_HOME>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${6:-Exit}" "${7:-1}" "1"
    return $?
  fi
  local CODEREPO_SCOPE="${1}"
  local CODEREPO_TYPE="${2}"
  local CODEREPO_NAME="${3}"
  local CODEREPO_SRC="${4}"
  local CODEREPO_HOME="${5:$REPO_DEFAULT_HOME}"
  echo "CodeRepoUpdate: Updating repository ${CODEREPO_NAME} of type ${CODEREPO_TYPE} for ${CODEREPO_SCOPE} using source ${CODEREPO_SRC}..."
  if [[ ! -d ${CODEREPO_SRC} ]]; then
    echo "CodeRepoUpdate: Failed to update repository ${CODEREPO_NAME} since the source ${CODEREPO_SRC} does not exist."
    ReturnOrExit "${6:-Exit}" "${7:-1}" "2"
    return $?
  fi
  local codeRepo_status
  local codeRepo_ret_code
  case "${CODEREPO_TYPE}" in
  'aws' | 'AWS' | 'codecommit' | 'CodeCommit')
    . "${SCRIPT_DEFAULT_HOME}/awsCommit.sh"
    IsAvailable f AWSCommitCopy "CodeCommit copy (AWSCommitCopy) function"
    codeRepo_status=$(AWSCommitCopy "${CODEREPO_SCOPE}" "${CODEREPO_NAME}" "${CODEREPO_SRC}" "${CODEREPO_HOME}" 'r')
    codeRepo_ret_code=$?
    ;;

  'GCP')
    . "${SCRIPT_DEFAULT_HOME}/gcpSrcRepo.sh"
    IsAvailable f GCPSourceRepoCopy "GCP Source Repo Copy (GCPSourceRepoCopy) function"
    codeRepo_status=$(GCPSourceRepoCopy "${CODEREPO_SCOPE}" "${CODEREPO_NAME}" "${CODEREPO_SRC}" "${CODEREPO_HOME}" 'r')
    codeRepo_ret_code=$?
    ;;

  *)
    echo "CodeRepoUpdate: Only AWS Code commit and GCP Source Repo is currently supported."
    ReturnOrExit "${6:-Exit}" "${7:-1}" "4"
    return $?
    ;;

  esac
  if [[ $codeRepo_ret_code -ne 0 ]]; then
    echo "CodeRepoUpdate: Failed to update ${CODEREPO_TYPE} due to error code ${codeRepo_ret_code}"
    echo "${codeRepo_status}"
    ReturnOrExit "${6:-Exit}" "${7:-1}" "3"
    return $?
  else
    echo "${codeRepo_status}"
  fi
  echo "CodeRepoUpdate: Updated repository ${CODEREPO_NAME} of type ${CODEREPO_TYPE} for ${CODEREPO_SCOPE}."
}

function CodeRepoCommit() {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ]; then
    echo 'CodeRepoCommit <Scope> <Code repo type: AWS|Github> <Repo name> [Commit message] [<REPO_HOME>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${6:-Exit}" "${7:-1}" "2"
    return $?
  fi
  local CODEREPO_SCOPE="${1}"
  local CODEREPO_TYPE="${2}"
  local CODEREPO_NAME="${3}"
  local CODEREPO_MSG="${4}"
  local CODEREPO_HOME="${5:$REPO_DEFAULT_HOME}"
  echo "CodeRepoCommit: Committing changes to repository ${CODEREPO_NAME} of type ${CODEREPO_TYPE} for ${CODEREPO_SCOPE}..."
  case "${CODEREPO_TYPE}" in
  'aws' | 'AWS' | 'codecommit' | 'CodeCommit')
    . "${SCRIPT_DEFAULT_HOME}/awsCommit.sh"
    IsAvailable f AWSCommitPush "CodeCommit push (AWSCommitPush) function"
    local codeRepo_status
    codeRepo_status=$(AWSCommitPush "${CODEREPO_SCOPE}" "${CODEREPO_NAME}" "${CODEREPO_MSG}" "${CODEREPO_HOME}" 'r')
    local codeRepo_ret_code=$?
    if [[ $codeRepo_ret_code -eq 0 ]]; then
      echo "${codeRepo_status}"
    elif [ $codeRepo_ret_code -eq 4 ]; then
      echo "${codeRepo_status}"
      echo "CodeRepoCommit: No change to commit to repository ${CODEREPO_NAME} of type ${CODEREPO_TYPE} for ${CODEREPO_SCOPE}."
      return 1
    else
      echo "CodeRepoCommit: Failed to commit ${CODEREPO_TYPE} due to error code ${codeRepo_ret_code}"
      echo "${codeRepo_status}"
      ReturnOrExit "${6:-Exit}" "${7:-1}" "3"
      return $?
    fi
    ;;

  'GCP')
    . "${SCRIPT_DEFAULT_HOME}/gcpSrcRepo.sh"
    IsAvailable f GCPSourceRepoPush "GCP Source Repo Push (GCPSourceRepoPush) function"
    local codeRepo_status
    codeRepo_status=$(GCPSourceRepoPush "${CODEREPO_SCOPE}" "${CODEREPO_NAME}" "${CODEREPO_MSG}" "${CODEREPO_HOME}" 'r')
    local codeRepo_ret_code=$?
    if [[ $codeRepo_ret_code -eq 0 ]]; then
      echo "${codeRepo_status}"
    elif [ $codeRepo_ret_code -eq 4 ]; then
      echo "${codeRepo_status}"
      echo "CodeRepoCommit: No change to commit to repository ${CODEREPO_NAME} of type ${CODEREPO_TYPE} for ${CODEREPO_SCOPE}."
      return 1
    else
      echo "CodeRepoCommit: Failed to commit ${CODEREPO_TYPE} due to error code ${codeRepo_ret_code}"
      echo "${codeRepo_status}"
      ReturnOrExit "${6:-Exit}" "${7:-1}" "3"
      return $?
    fi
    ;;

  *)
    echo "CodeRepoCommit: Only AWS Code commit and GCP Source Repo is currently supported."
    ReturnOrExit "${6:-Exit}" "${7:-1}" "4"
    return $?
    ;;

  esac
  echo "CodeRepoCommit: Committed changes to repository ${CODEREPO_NAME} of type ${CODEREPO_TYPE} for ${CODEREPO_SCOPE}."
}

function CodeRepoCleanup() {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ]; then
    echo 'CodeRepoCleanup <Scope> <Code repo type: AWS|Github> <Repo name> [<REPO_HOME>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${5:-Exit}" "${6:-1}" "1"
    return $?
  fi
  local CODEREPO_SCOPE="${1}"
  local CODEREPO_TYPE="${2}"
  local CODEREPO_NAME="${3}"
  local CODEREPO_HOME="${4:$REPO_DEFAULT_HOME}"
  echo "CodeRepoCleanup: Cleaning up repository ${CODEREPO_NAME} of type ${CODEREPO_TYPE} for ${CODEREPO_SCOPE}..."
  local codeRepo_status
  local codeRepo_ret_code
  case "${CODEREPO_TYPE}" in
  'aws' | 'AWS' | 'codecommit' | 'CodeCommit')
    . "${SCRIPT_DEFAULT_HOME}/awsCommit.sh"
    IsAvailable f AWSCommitCleanup "CodeCommit cleanup (AWSCommitCleanup) function"
    codeRepo_status=$(AWSCommitCleanup "${CODEREPO_SCOPE}" "${CODEREPO_NAME}" "${CODEREPO_HOME}" 'r')
    codeRepo_ret_code=$?
    ;;

  'GCP')
    . "${SCRIPT_DEFAULT_HOME}/gcpSrcRepo.sh"
    IsAvailable f GCPSourceRepoCleanup "GCP Source Repo cleanup (GCPSourceRepoCleanup) function"
    codeRepo_status=$(GCPSourceRepoCleanup "${CODEREPO_SCOPE}" "${CODEREPO_NAME}" "${CODEREPO_HOME}" 'r')
    codeRepo_ret_code=$?
    ;;

  *)
    echo "CodeRepoCleanup: Only AWS Code commit and Github type is currently supported."
    ReturnOrExit "${5:-Exit}" "${6:-1}" "3"
    return $?
    ;;

  esac
  if [[ $codeRepo_ret_code -ne 0 ]]; then
    echo "CodeRepoCleanup: Failed to cleanup ${CODEREPO_TYPE} due to error code ${codeRepo_ret_code}"
    echo "${codeRepo_status}"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "2"
    return $?
  else
    echo "${codeRepo_status}"
  fi
  echo "CodeRepoCleanup: Cleaned up repository ${CODEREPO_NAME} of type ${CODEREPO_TYPE} for ${CODEREPO_SCOPE}."
}
