SCRIPT_DEFAULT_HOME=$(cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}" )" &> /dev/null && pwd)
TF_DEFAULT_HOME=$(pwd)
TF_DEFAULT_STATE_PACK_FILE_SUFFIX="_terraform_state"
TF_DEFAULT_STATE_PACK_FILE_EXTENSION=".tar.gz"

. "${SCRIPT_DEFAULT_HOME}"/basic.sh

IsAvailable c 'terraform' "Terraform CLI"

function TFHome {
  if [[ "${1}" == "" ]];
  then
    echo 'TFHome <Scope> [<TF_HOME:'" ${TF_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${3:-Exit}" "${4:-1}" "1"; return $?
  fi
  local TF_SCOPE="${1}"
  local TF_HOME="${2:-$TF_DEFAULT_HOME}"
  local TF_BASE="${TF_HOME}/${TF_SCOPE}_terraform"
  if [ ! -d "${TF_BASE}" ];
  then
    mkdir -p "${TF_BASE}"
  fi
  echo "${TF_BASE}"
  return 0
}

function TFStatePackFileName {
  if [[ "${1}" == "" ]];
  then
    echo 'TFStatePackFileName <Scope> [<TF_HOME:'" ${TF_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${3:-Exit}" "${4:-1}" "1"; return $?
  fi
  local TF_SCOPE="${1}"
  local TF_HOME="${2:-$TF_DEFAULT_HOME}"
  local TF_STATE_PACK="${TF_SCOPE}${TF_DEFAULT_STATE_PACK_FILE_SUFFIX}${TF_DEFAULT_STATE_PACK_FILE_EXTENSION}"
  echo "${TF_STATE_PACK}"
  return 0
}

function TFStatePackFilePath {
  if [[ "${1}" == "" ]];
  then
    echo 'TFStatePackFileName <Scope> [<TF_HOME:'" ${TF_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${3:-Exit}" "${4:-1}" "1"; return $?
  fi
  local TF_SCOPE="${1}"
  local TF_HOME="${2:-$TF_DEFAULT_HOME}"
  local TF_STATE_PACK_FILE_NAME
  TF_STATE_PACK_FILE_NAME=$(TFStatePackFileName "${TF_SCOPE}" "${TF_HOME}")
  local TF_STATE_PACK_PATH="${TF_HOME}/${TF_STATE_PACK_FILE_NAME}"
  echo "${TF_STATE_PACK_PATH}"
  return 0
}

function TFStatePack {
  if [[ "${1}" == "" ]];
  then
    echo 'TFStatePack <Scope> [<TF_HOME:'" ${TF_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${3:-Exit}" "${4:-1}" "1"; return $?
  fi
  IsAvailable Command tar "tar"
  IsAvailable Command gzip "GZip"

  local TF_BASE; TF_BASE=$(TFHome "${1}" "${2}")
  if [[ ! -d "${TF_BASE}" ]];
  then
    echo "TFStatePack: No terraform state directory exists at ${TF_BASE}"
    ReturnOrExit "${3:-Exit}" "${4:-1}" "2"; return $?
  fi
  echo "TFStatePack: Deleting terraform files from ${TF_BASE}."
  rm "${TF_BASE}"/*tf
  rm "${TF_BASE}"/*tpl
  echo "TFStatePack: Deleting terraform providers."
  rm -rf "${TF_BASE}/.terraform/providers"
  local TF_STATE_PACK_FILE_PATH;TF_STATE_PACK_FILE_PATH=$(TFStatePackFilePath "${1}" "${2}")
  local TF_STATE_PACK_FILE_PATH_PREFIX=${TF_STATE_PACK_FILE_PATH%"$TF_DEFAULT_STATE_PACK_FILE_EXTENSION"}
  if [[ -f "${TF_STATE_PACK_FILE_PATH_PREFIX}.tar" ]];
  then
    echo "TFStatePack: Deleting exiting tar file ${TF_STATE_PACK_FILE_PATH_PREFIX}.tar."
    rm "${TF_STATE_PACK_FILE_PATH_PREFIX}.tar"
  fi
  echo "TFStatePack: creating tar from directory ${TF_BASE}."
  state_tar_status=$(tar -cvf "${TF_STATE_PACK_FILE_PATH_PREFIX}.tar" -C "${TF_BASE}" . 2>&1)
  state_tar_ret_code=$?
  if [[ $state_tar_ret_code -ne 0 ]];
  then
    echo "TFStatePack: Failed to pack the terraform state content at ${TF_BASE} due to error ${state_tar_ret_code}"
    echo "${state_tar_status}"
    ReturnOrExit "${3:-Exit}" "${4:-1}" "3"; return $?
  fi
  echo "TFStatePack: created tar at ${TF_STATE_PACK_FILE_PATH_PREFIX}.tar"
  if [[ -f "${TF_STATE_PACK_FILE_PATH_PREFIX}.tar.gz" ]];
  then
    echo "TFStatePack: Deleting exiting tar.gz file ${TF_STATE_PACK_FILE_PATH_PREFIX}.tar.gz"
    rm "${TF_STATE_PACK_FILE_PATH_PREFIX}.tar.gz"
  fi
  echo "TFStatePack: GZipping tar file ${TF_STATE_PACK_FILE_PATH_PREFIX}.tar"
  state_gzip_status=$(gzip "${TF_STATE_PACK_FILE_PATH_PREFIX}.tar" 2>&1)
  state_gzip_ret_code=$?
  if [[ $state_gzip_ret_code -ne 0 ]];
  then
    echo "TFStatePack: Failed to pack the terraform state content due to error ${state_gzip_ret_code} during gzip"
    echo "${state_gzip_status}"
    ReturnOrExit "${3:-Exit}" "${4:-1}" "4"; return $?
  fi
  echo "TFStatePack: GZipped tar file."
  echo "TFStatePack: Deleting the terraform directory ${TF_BASE}"
  rm -rf "${TF_BASE}"
}

function TFStateUnPack {
  if [[ "${1}" == "" ]];
  then
    echo 'TFStateUnPack <Scope> [<TF_HOME:'" ${TF_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${3:-Exit}" "${4:-1}" "1"; return $?
  fi
  IsAvailable Command tar "tar"
  IsAvailable Command gunzip "GUnzip "
  local TF_BASE; TF_BASE=$(TFHome "${1}" "${2}")
  local TF_STATE_PACK_FILE_PATH;TF_STATE_PACK_FILE_PATH=$(TFStatePackFilePath "${1}" "${2}")
  local TF_STATE_PACK_FILE_PATH_PREFIX=${TF_STATE_PACK_FILE_PATH%"$TF_DEFAULT_STATE_PACK_FILE_EXTENSION"}
  if [[ ! -f "${TF_STATE_PACK_FILE_PATH}" ]] && [[ ! -f "${TF_STATE_PACK_FILE_PATH_PREFIX}.tar" ]];
  then
    echo "TFStateUnPack: Expected file ${TF_STATE_PACK_FILE_PATH} or ${TF_STATE_PACK_FILE_PATH_PREFIX}.tar to be present"
    ReturnOrExit "${3:-Exit}" "${4:-1}" "2"; return $?
  fi
  if [[ -f "${TF_STATE_PACK_FILE_PATH}" ]];
  then
    echo "TFStateUnPack: Unzipping the file ${TF_STATE_PACK_FILE_PATH}"
    state_gzip_status=$(gunzip "${TF_STATE_PACK_FILE_PATH}" 2>&1)
    state_gzip_ret_code=$?
    if [[ $state_gzip_ret_code -ne 0 ]];
    then
      echo "TFStatePack: Failed to unzip the state file  due to error ${state_gzip_ret_code}"
      echo "${state_gzip_status}"
      ReturnOrExit "${3:-Exit}" "${4:-1}" "3"; return $?
    fi
  fi
  echo "TFStateUnPack: Un-tar the file ${TF_STATE_PACK_FILE_PATH_PREFIX}.tar"
  state_tar_status=$(tar -xvf "${TF_STATE_PACK_FILE_PATH_PREFIX}.tar" -C "${TF_BASE}" 2>&1)
  state_tar_ret_code=$?
  if [[ $state_tar_ret_code -ne 0 ]];
  then
    echo "TFStateUnPack: Failed to unpack the terraform state content to ${TF_BASE} from ${TF_STATE_PACK_FILE_PATH_PREFIX}.tar due to error ${state_tar_ret_code}"
    echo "${state_tar_status}"
    ReturnOrExit "${3:-Exit}" "${4:-1}" "4"; return $?
  fi
  if [[ ! -d "${TF_BASE}" ]];
  then
    echo "TFStateUnPack: No terraform state directory was created after tar at ${TF_BASE}"
    ReturnOrExit "${3:-Exit}" "${4:-1}" "5"; return $?
  fi
  if [[ -f "${TF_STATE_PACK_FILE_PATH_PREFIX}.tar" ]];
  then
    echo "TFStateUnPack: Deleting tar file ${TF_STATE_PACK_FILE_PATH_PREFIX}.tar after extraction."
    rm "${TF_STATE_PACK_FILE_PATH_PREFIX}.tar"
  fi
}

function TFCleanup {
  if [[ "${1}" == "" ]];
  then
    echo 'TFCleanup <Scope> [<TF_HOME:'" ${TF_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${3:-Exit}" "${4:-1}" "1"; return $?
  fi
  local TF_SCOPE="${1}"
  local TF_HOME="${2:-$TF_DEFAULT_HOME}"
  local TF_BASE;
  TF_BASE=$(TFHome "${TF_SCOPE}" "${TF_HOME}")
  if [[ -d "${TF_BASE}" ]];
  then
    echo "TFCleanup: Deleting terraform state directory ${TF_BASE}."
    rm -rf "${TF_BASE}"
  fi
}

function TFInit {
  if [[ "${1}" == "" ]];
  then
    echo 'TFInit <Scope> [<TF_HOME:'" ${TF_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${3:-Exit}" "${4:-1}" "1"; return $?
  fi
  local TF_SCOPE="${1}"
  local TF_HOME="${2:-$TF_DEFAULT_HOME}"
  local TF_BASE;
  TF_BASE=$(TFHome "${TF_SCOPE}" "${TF_HOME}")
  local TF_PLUGINS="${TF_BASE}/.plugins"
  local TF_BACKEND_CFG="${TF_BASE}/backend.cfg"
  local TF_DOWNLOAD_PLUGIN="${TF_DOWNLOAD_PLUGIN:-false}"
  local TF_STATE="${TF_BASE}/${TF_SCOPE}_terraform.tfstate"

  echo "TFInit: Creating base directory ${TF_BASE}."
  mkdir -p "${TF_BASE}"
  mkdir -p "${TF_PLUGINS}"
  local copy_status
  echo "TFInit: Copying 'tf' files to base directory."
  copy_status=$(cp -R ./*.tf ./*.tpl "${TF_BASE}" 2>&1)
  local copy_ret_val=$?
  if [ $copy_ret_val -ne 0 ];
  then
    echo "TFApply: Failed to copy file to terraform home directory with error ${copy_ret_val}. TF_BASE=${TF_BASE}"
    echo "${copy_status}"
    ReturnOrExit "${3:-Exit}" "${4:-1}" "2"; return $?
  fi
  if [ ! -f "${TF_BACKEND_CFG}" ];
  then
    echo "TFInit: Creating backend config ${TF_BACKEND_CFG}."
    echo 'path="'"${TF_STATE}"'"' > "${TF_BACKEND_CFG}"
  fi
  local init_status
  local init_ret_code
  if [ "${TF_DOWNLOAD_PLUGIN}" == "true" ];
  then
    echo "TFInit: Terraform init...."
    init_status=$(terraform -chdir="${TF_BASE}" init -backend-config="${TF_BACKEND_CFG}" -input=false -no-color 2>&1)
    init_ret_code=$?
  else
    init_status=$(terraform -chdir="${TF_BASE}" init -backend-config="${TF_BACKEND_CFG}"  -get="${TF_DOWNLOAD_PLUGIN:-false}" -input=false -no-color -plugin-dir="${TF_PLUGINS}" 2>&1)
    init_ret_code=$?
  fi
  if [ $init_ret_code -ne 0 ];
  then
    echo "TFInit: Failed to initialize terraform with return error code ${init_ret_code}. TF_BASE=${TF_BASE}"
    echo "${init_status}"
    ReturnOrExit "${3:-Exit}" "${4:-1}" "3"; return $?
  else
    echo "${init_status}"
  fi
  if [[ "${TF_DOWNLOAD_PLUGIN}" == "true" ]];
  then
    echo "TFInit: Copying downloaded plugins to ${TF_PLUGINS}"
    cp -R "${TF_BASE}/.terraform/providers/." "${TF_PLUGINS}"
  fi
}

function TFApply {
  if [[ "${1}" == "" ]];
  then
    echo 'TFApply <Scope> [<Operation: Update*|Replace|Destroy>] [<Target: name of specific resource>] [<TF_HOME:'" ${TF_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${5:-Exit}" "${6:-1}" "2"; return $?
  fi
  local TF_SCOPE="${1}"
  local TF_OPS="${2:-Update}"
  local TF_TARGET="${3}"
  local TF_HOME="${4:-$TF_DEFAULT_HOME}"
  local TF_BASE="${TF_HOME}/${TF_SCOPE}_terraform"
  local TF_CURR_TIME
  TF_CURR_TIME=$(date '+%Y%m%d%Z%H%M%S')
  local TF_STATE_BACKUP_ROOT="${TF_BASE}/.states"
  local TF_STATE_BACKUP="${TF_STATE_BACKUP_ROOT}/terraform_${TF_CURR_TIME}.tfstate.backup"
  local TF_STATE="${TF_BASE}/${TF_SCOPE}_terraform.tfstate"
  local TF_PLAN_ROOT="${TF_BASE}/.plans/"
  local TF_PLAN="${TF_PLAN_ROOT}/terraform_${TF_CURR_TIME}.plan"
  local TF_VARS="${TF_BASE}/terraform.tfvars"

  echo "TFApply: Creating state and plan directories"
  mkdir -p "${TF_STATE_BACKUP_ROOT}"
  mkdir -p "${TF_PLAN_ROOT}"
  if [ ! -f "${TF_VARS}" ];
  then
    echo "TFApply: Creating terraform.tfvars file"
    echo 'ENV_NAME = "'"${TF_SCOPE}"'"' > "${TF_VARS}"
    echo 'TF_BASE = "'"${TF_BASE}"'"' >> "${TF_VARS}"
  fi
  local validate_status
  echo "TFApply: Validating terraform configuration..."
  validate_status=$(terraform -chdir="${TF_BASE}" validate -no-color 2>&1)
  local validate_ret_code=$?
  if [ $validate_ret_code -ne 0 ];
  then
    echo "TFApply: Failed to validate the terraform script with return error code ${validate_status}. TF_BASE=${TF_BASE}"
    echo "${validate_status}"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "3"; return $?
  fi
  local plan_command="terraform -chdir=${TF_BASE} plan -no-color -input=false -detailed-exitcode -compact-warnings -state=${TF_STATE} -out=${TF_PLAN} -var-file=${TF_VARS} "
  case "${TF_OPS}" in

    r|R|Replace|replace)
      if [[ "${TF_TARGET}" != "" ]];
      then
        plan_command="${plan_command} -replace=${TF_TARGET} "
      else
        echo "TFApply: Failed to plan since the operation replace was provided but no assocated target was provided. TF_BASE=${TF_BASE}"
        ReturnOrExit "${5:-Exit}" "${6:-1}" "4"; return $?
      fi
      ;;

    d|D|Destroy|destroy)
      plan_command="${plan_command} -destroy "
      if [[ "${TF_TARGET}" != "" ]];
      then
        plan_command="${plan_command} -target=${TF_TARGET} "
      fi
      ;;

    u|U|Update|update|*)
      if [[ "${TF_TARGET}" != "" ]];
      then
        plan_command="${plan_command} -target=${TF_TARGET} "
      fi
      ;;

  esac
  local plan_status
  echo "TFApply: Generating plan using command ${plan_command}"
  plan_status=$($plan_command 2>&1)
  local plan_ret_code=$?
  if [ $plan_ret_code -eq 1 ];
  then
    echo "${plan_status}"
    echo "TFApply: Failed to plan for terraform script with return error code ${plan_ret_code}. TF_BASE=${TF_BASE}"
    ReturnOrExit "${5:-Exit}" "${6:-1}" "5"; return $?
  else
    echo "${plan_status}"
  fi
  if [ $plan_ret_code -eq 0 ];
  then
    echo "TFApply: No new change to the configuration was detected. Deleting the plan and skipping apply..."
    rm "${TF_PLAN}"
    return 1
  fi
  if [ $plan_ret_code -eq 2 ];
  then
    local apply_status
    apply_status=$(terraform -chdir="${TF_BASE}" apply -no-color -compact-warnings -input=false -auto-approve -backup="${TF_STATE_BACKUP}" -state="${TF_STATE}" "${TF_PLAN}"  2>&1)
    local apply_ret_code=$?
    if [ $apply_ret_code -ne 0 ];
    then
      echo "TFApply: Failed to apply the terraform script with return error code ${apply_ret_code}"
      echo "${apply_status}"
      ReturnOrExit "${5:-Exit}" "${6:-1}" "6"; return $?
    else
      echo "${apply_status}"
    fi
  fi
}

function TFGetConfig {
  if [[ "${1}" == "" ]] || [[ "${2}" == "" ]];
  then
    echo 'TFGetConfig <Scope> <Key name> [<TF_HOME:'" ${TF_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${4:-Exit}" "${5:-1}" "1"; return $?
  fi
  local TF_SCOPE="${1}"
  local TF_KEY_NAME="${2}"
  local TF_HOME="${3:-$TF_DEFAULT_HOME}"
  local TF_BASE="${TF_HOME}/${TF_SCOPE}_terraform"

  if [ ! -d "${TF_BASE}" ];
  then
    echo "TFGetConfig: Failed to return config due to missing terraform directory ${TF_BASE}"
    ReturnOrExit "${4:-Exit}" "${5:-1}" "2"; return $?
  fi
  local output_status
  output_status=$(terraform -chdir="${TF_BASE}" output "${TF_KEY_NAME}" 2>&1)
  output_ret_code=$?
  if [ $output_ret_code -ne 0 ];
  then
    echo "TFGetConfig: Failed to retrieve the property ${TF_KEY_NAME} from terraform directory ${TF_BASE}"
    echo "${output_status}"
    ReturnOrExit "${4:-Exit}" "${5:-1}" "3"; return $?
  fi
  output_value=$(echo "${output_status}" | cut -f 2 -d '"')
  echo "${output_value}"
}


