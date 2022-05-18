SCRIPT_DEFAULT_HOME=$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd)
CMT_DEFAULT_HOME=$(pwd)

. "${SCRIPT_DEFAULT_HOME}"/basic.sh
. "${SCRIPT_DEFAULT_HOME}"/aws.sh

IsAvailable c aws "AWS CLI"
IsAvailable c git "GIT CLI"

function AWSCodeCommitHome {
  if [ "${1}" == "" ] || [ "${2}" == "" ];
  then
    echo 'TFHome <Scope> <Repo name> [<Home: '" ${CMT_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${4:-Exit}" "${5:-1}" "1"; return $?
  fi
  local CMT_SCOPE="${1}"
  local CMT_NAME="${2}"
  local CMT_HOME="${3:-$CMT_DEFAULT_HOME}"
  local CMT_BASE="${CMT_HOME}/${CMT_SCOPE}_awscommit_${CMT_NAME}"
  if [ ! -d "${CMT_BASE}" ];
  then
    mkdir -p "${CMT_BASE}"
  fi
  echo "${CMT_BASE}"
  return 0
}

function AWSCommitInit {
  if [[ "${1}" == "" ]] || [[ "${2}" == "" ]];
  then
    echo 'AWSCommitInit <Scope> <Repo name> [<Home: '" ${CMT_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${4:-Exit}" "${5:-1}" "1"; return $?
  fi
  local CMT_SCOPE="${1}"
  local CMT_NAME="${2}"
  local CMT_HOME="${3:-$CMT_DEFAULT_HOME}"
  local CMT_BASE;
  CMT_BASE=$(AWSCodeCommitHome "${CMT_SCOPE}" "${CMT_NAME}" "${CMT_HOME}")
  if [[ "${AWS_REGION}" == "" ]];
  then
    echo "AWSCommitInit: Failed to initialize codecommit for repository ${CMT_NAME} due to missing region name."
    ReturnOrExit "${4:-Exit}" "${5:-1}" "3"; return $?
  fi
  if [[ -d ${CMT_BASE}/.git ]];
  then
    echo "AWSCommitInit: Removing existing repository from ${CMT_BASE}"
    rm -rf ${CMT_BASE}
  fi
  echo "AWSCommitInit: Setting up the configuration ${TF_BASE}."
  git config --global "credential.https://git-codecommit.${AWS_REGION}.amazonaws.com/v1/repos/${CMT_NAME}.helper" '!aws codecommit credential-helper $@'
  local helper_ret_val=$?
  if [[ $helper_ret_val -ne 0 ]];
  then
    echo "AWSCommitInit: Failed to set the git global credential helper for git repo ${CMT_NAME} with error ${helper_ret_val}. CMT_BASE=${CMT_BASE}"
    ReturnOrExit "${4:-Exit}" "${5:-1}" "4"; return $?
  fi
  git config --global "credential.https://git-codecommit.${AWS_REGION}.amazonaws.com/v1/repos/${CMT_NAME}.UseHttpPath" 'true'
  local httpPath_ret_val=$?
  if [[ $httpPath_ret_val -ne 0 ]];
  then
    echo "AWSCommitInit: Failed to set the git global http path setting for git repo ${CMT_NAME} with error ${httpPath_ret_val}. CMT_BASE=${CMT_BASE}"
    ReturnOrExit "${4:-Exit}" "${5:-1}" "5"; return $?
  fi
  local clone_status
  echo "AWSCommitInit: Cloning repository..."
  clone_status=$(git clone https://git-codecommit.${AWS_REGION}.amazonaws.com/v1/repos/${CMT_NAME} ${CMT_BASE} 2>&1)
  local clone_ret_val=$?
  if [ $clone_ret_val -ne 0 ];
  then
    echo "AWSCommitInit: Failed to clone git repo ${CMT_NAME} with error ${clone_ret_val}. CMT_BASE=${CMT_BASE}"
    echo "${clone_status}"
    ReturnOrExit "${4:-Exit}" "${5:-1}" "2"; return $?
  fi
}

function AWSCommitCopy {
  if [[ "${1}" == "" ]] || [[ "${2}" == "" ]] || [[ "${3}" == "" ]];
  then
    echo 'AWSCommitCopy <Scope> <Repo name> <Source code path> [<Home: '" ${CMT_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${5:-Exit}" "${6:-1}" "1"; return $?
  fi
  local CMT_SCOPE="${1}"
  local CMT_NAME="${2}"
  local CMT_SRC="${3}"
  local CMT_HOME="${4:-$CMT_DEFAULT_HOME}"
  local CMT_BASE;
  CMT_BASE=$(AWSCodeCommitHome "${CMT_SCOPE}" "${CMT_NAME}" "${CMT_HOME}")
  if [[ ! -d ${CMT_BASE} ]];
  then
    echo "AWSCommitCopy: Failed to copy the updates to repo ${CMT_NAME} due to missing repository. Please initialize repo before copy. CMT_BASE=${CMT_BASE}"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "2"; return $?
  fi
  if [[ ! -d ${CMT_SRC} ]];
  then
    echo "AWSCommitCopy: Failed to copy the updates to repo ${CMT_NAME} since source directory ${CMT_SRC} does not exist. CMT_BASE=${CMT_BASE}"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "3"; return $?
  fi
  echo "AWSCommitCopy: Copying files from ${CMT_SRC} to ${CMT_BASE}"
  cp -R "${CMT_SRC}" "${CMT_BASE}"
  local copy_ret_val=$?
  if [[ $copy_ret_val -ne 0 ]];
  then
    echo "AWSCommitCopy: Failed to copy updates to git repo ${CMT_NAME} with error ${copy_ret_val}. CMT_BASE=${CMT_BASE}"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "4"; return $?
  fi
}

function AWSCommitPush {
  if [[ "${1}" == "" ]] || [[ "${2}" == "" ]];
  then
    echo 'AWSCommitPush <Scope> <Repo name> [<Commit message>] [<Home: '" ${CMT_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${5:-Exit}" "${6:-1}" "1"; return $?
  fi
  local CMT_SCOPE="${1}"
  local CMT_NAME="${2}"
  local CMT_MSG="${3:-Change made}"
  local CMT_HOME="${4:-$CMT_DEFAULT_HOME}"
  local CMT_BASE;
  CMT_BASE=$(AWSCodeCommitHome "${CMT_SCOPE}" "${CMT_NAME}" "${CMT_HOME}")
  if [[ ! -d ${CMT_BASE}/.git ]];
  then
    echo "AWSCommitPush: Failed to commit updates to repo ${CMT_NAME} since the location is not initialized. Please initialize repo before copy. CMT_BASE=${CMT_BASE}"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "2"; return $?
  fi
  echo "AWSCommitPush: Adding files...."
  git "--git-dir=${CMT_BASE}/.git" "--work-tree=${CMT_BASE}/" add .
  local copy_ret_val=$?
  if [[ $copy_ret_val -ne 0 ]];
  then
    echo "AWSCommitPush: Failed to add files for commit to ${CMT_NAME} with error ${copy_ret_val}. CMT_BASE=${CMT_BASE}"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "3"; return $?
  fi
  echo "AWSCommitPush: Committing changes...."
  git "--git-dir=${CMT_BASE}/.git" "--work-tree=${CMT_BASE}/" commit -m "${CMT_MSG}"
  copy_ret_val=$?
  if [[ $copy_ret_val -ne 0 ]];
  then
    echo "AWSCommitPush: Failed to commit to ${CMT_NAME} with error ${copy_ret_val}. CMT_BASE=${CMT_BASE}"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "4"; return $?
  fi
  echo "AWSCommitPush: Pushing updates...."
  git "--git-dir=${CMT_BASE}/.git" "--work-tree=${CMT_BASE}/" push
  copy_ret_val=$?
  if [[ $copy_ret_val -ne 0 ]];
  then
    echo "AWSCommitPush: Failed to push update to ${CMT_NAME} with error ${copy_ret_val}. CMT_BASE=${CMT_BASE}"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "5"; return $?
  fi
}

function AWSCommitCleanup {
  if [[ "${1}" == "" ]] || [[ "${2}" == "" ]];
  then
    echo 'AWSCommitCleanup <Scope> <Repo name> [<Home: '" ${CMT_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${4:-Exit}" "${5:-1}" "1"; return $?
  fi
  local CMT_SCOPE="${1}"
  local CMT_NAME="${2}"
  local CMT_HOME="${3:-$CMT_DEFAULT_HOME}"
  local CMT_BASE;
  CMT_BASE=$(AWSCodeCommitHome "${CMT_SCOPE}" "${CMT_NAME}" "${CMT_HOME}")
  if [[ "${AWS_REGION}" == "" ]];
  then
    echo "AWSCommitCleanup: Failed to cleanup repo ${CMT_NAME} since the AWS_REGION env variable is not set."
    ReturnOrExit "${4:-Exit}" "${5:-1}" "2"; return $?
  fi
  echo "AWSCommitCleanup: Deleting the local copy of repo at ${CMT_BASE}...."
  if [[ -d ${CMT_BASE}/.git ]];
  then
    rm -rf "${CMT_BASE}"
    delete_ret_val=$?
    if [[ $delete_ret_val -ne 0 ]];
    then
      echo "AWSCommitCleanup: Failed to delete the local copy of repo ${CMT_NAME} due to error code ${delete_ret_val}. CMT_BASE=${CMT_BASE}"
      ReturnOrExit "${4:-Exit}" "${5:-1}" "3"; return $?
    fi
  else
      echo "AWSCommitCleanup: Failed to delete the local copy of repo ${CMT_NAME} since the given location does not contain git repository. Please check the location. CMT_BASE=${CMT_BASE}"
      return 4
  fi
  echo "AWSCommitCleanup: Removing credential helper configuration..."
  git config --global --unset "credential.https://git-codecommit.${AWS_REGION}.amazonaws.com/v1/repos/${CMT_NAME}.helper"
  local helper_ret_val=$?
  if [[ $helper_ret_val -ne 0 ]];
  then
    echo "AWSCommitCleanup: Failed to unset the git global credential helper for git repo ${CMT_NAME} with error ${helper_ret_val}. CMT_BASE=${CMT_BASE}"
    ReturnOrExit "${4:-Exit}" "${5:-1}" "5"; return $?
  fi
  git config --global --unset "credential.https://git-codecommit.${AWS_REGION}.amazonaws.com/v1/repos/${CMT_NAME}.UseHttpPath"
  local helper_ret_val=$?
  if [[ $helper_ret_val -ne 0 ]];
  then
    echo "AWSCommitCleanup: Failed to unset the git global credential UseHttpPath setting for git repo ${CMT_NAME} with error ${helper_ret_val}. CMT_BASE=${CMT_BASE}"
    ReturnOrExit "${4:-Exit}" "${5:-1}" "6"; return $?
  fi
}
