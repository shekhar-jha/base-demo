SCRIPT_DEFAULT_HOME=$(cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}" )" &> /dev/null && pwd)
TF_DEFAULT_HOME=$(pwd)

. "${SCRIPT_DEFAULT_HOME}"/basic.sh

IsAvailable c 'terraform' "Terraform CLI"

function TFHome {
  if [[ "${1}" == "" ]];
  then
    echo 'TFHome <Scope> [<TF_HOME:'" ${TF_DEFAULT_HOME}"'>]' 
    return -1
  fi
  local TF_SCOPE="${1}"
  local TF_OPS="${2:-Update}"
  local TF_TARGET="${3}"
  local TF_HOME="${4:-$TF_DEFAULT_HOME}"
  local TF_BASE="${TF_HOME}/${TF_SCOPE}_terraform"
  if [ ! -d "${TF_BASE}" ];
  then
    mkdir -p "${TF_BASE}"
  fi
  echo "${TF_BASE}"
  return 0
}

function TFCleanup {
  if [[ "${1}" == "" ]];
  then
    echo 'TFCleanup <Scope> [<TF_HOME:'" ${TF_DEFAULT_HOME}"'>]' 
    return -1
  fi
  local TF_SCOPE="${1}"
  local TF_HOME="${2:-$TF_DEFAULT_HOME}"
  local TF_BASE="${TF_HOME}/${TF_SCOPE}_terraform"
  local TF_PLUGINS="${TF_BASE}/.plugins"
  local TF_CURR_TIME 
  TF_CURR_TIME=$(date '+%Y%m%d%Z%H%M%S')
  local TF_STATE_BACKUP_ROOT="${TF_BASE}/.states"
  local TF_VARS="${TF_BASE}/terraform.tfvars"
  local TF_BACKEND_CFG="${TF_BASE}/backend.cfg"
  local TF_DOWNLOAD_PLUGIN="${TF_DOWNLOAD_PLUGIN:-false}"
  rm "${TF_BASE}/*tf"
  rm -rf "${TF_BASE}/.terraform/providers"
}

function TFApply {
  if [[ "${1}" == "" ]];
  then
    echo 'TFApply <Scope> [<Operation: Update*|Replace|Destroy>] [<Target: name of specific resource>] [<TF_HOME:'" ${TF_DEFAULT_HOME}"'>]' 
    return -1
  fi
  local TF_SCOPE="${1}"
  local TF_OPS="${2:-Update}"
  local TF_TARGET="${3}"
  local TF_HOME="${4:-$TF_DEFAULT_HOME}"
  local TF_BASE="${TF_HOME}/${TF_SCOPE}_terraform"
  local TF_PLUGINS="${TF_BASE}/.plugins"
  local TF_CURR_TIME 
  TF_CURR_TIME=$(date '+%Y%m%d%Z%H%M%S')
  local TF_STATE_BACKUP_ROOT="${TF_BASE}/.states"
  local TF_STATE_BACKUP="${TF_STATE_BACKUP_ROOT}/terraform_${TF_CURR_TIME}.tfstate.backup"
  local TF_STATE="${TF_BASE}/${TF_SCOPE}_terraform.tfstate"
  local TF_PLAN_ROOT="${TF_BASE}/.plans/"
  local TF_PLAN="${TF_PLAN_ROOT}/terraform_${TF_CURR_TIME}.plan"
  local TF_VARS="${TF_BASE}/terraform.tfvars"
  local TF_BACKEND_CFG="${TF_BASE}/backend.cfg"
  local TF_DOWNLOAD_PLUGIN="${TF_DOWNLOAD_PLUGIN:-false}"
  
  if [ ! -d "${TF_BASE}" ];
  then
    mkdir -p "${TF_BASE}"
    mkdir -p "${TF_PLUGINS}"
    mkdir -p "${TF_STATE_BACKUP_ROOT}"
    mkdir -p "${TF_PLAN_ROOT}"
  fi
  local copy_status
  copy_status=$(cp -R *.tf "${TF_BASE}" 2>&1)
  local copy_ret_val=$?
  if [ $copy_ret_val -ne 0 ];
  then
    echo "TFApply: Failed to copy file to terraform home directory with error ${init_ret_code}. TF_BASE=${TF_BASE}"
    echo "${copy_status}"
    return -7    
  fi
  if [ ! -f "${TF_VARS}" ];
  then
    echo "TFApply: Creating terraform.tfvars file"
    echo 'ENV_NAME = "'"${TF_SCOPE}"'"' > "${TF_VARS}"
    echo 'TF_BASE = "'"${TF_BASE}"'"' >> "${TF_VARS}"
  fi
  if [ ! -f "${TF_BACKEND_CFG}" ];
  then  
    echo 'path="'"${TF_STATE}"'"' > "${TF_BACKEND_CFG}"
  fi
  local init_status
  local init_ret_code
  if [ "${TF_DOWNLOAD_PLUGIN}" == "true" ];
  then
    init_status=$(terraform -chdir="${TF_BASE}" init -backend-config="${TF_BACKEND_CFG}" -input=false -no-color 2>&1)
    init_ret_code=$?
  else
    init_status=$(terraform -chdir="${TF_BASE}" init -backend-config="${TF_BACKEND_CFG}"  -get=${TF_DOWNLOAD_PLUGIN:-false} -input=false -no-color -plugin-dir="${TF_PLUGINS}" 2>&1)
    init_ret_code=$?
  fi
  if [ $init_ret_code -ne 0 ];
  then
    echo "TFApply: Failed to initialize terraform with return error code ${init_ret_code}. TF_BASE=${TF_BASE}"
    echo "${init_status}"
    return -2
  fi
  local validate_status
  validate_status=$(terraform -chdir="${TF_BASE}" validate -no-color 2>&1)
  local validate_ret_code=$?
  if [ $validate_ret_code -ne 0 ];
  then
    echo "TFApply: Failed to validate the terraform script with return error code ${validate_status}. TF_BASE=${TF_BASE}"
    echo "${validate_status}"
    return -3
  fi
  local plan_command="terraform -chdir=${TF_BASE} plan -no-color -input=false -detailed-exitcode -compact-warnings -state=${TF_STATE} -out=${TF_PLAN} -var-file=${TF_VARS} "
  case "${TF_OPS}" in 
  
    r|R|Replace|replace)
      if [[ "${TF_TARGET}" != "" ]];
      then
        plan_command="${plan_command} -replace=${TF_TARGET} "
      else
        echo "TFApply: Failed to plan since the operation replace was provided but no assocated target was provided. TF_BASE=${TF_BASE}"
        return -4
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
  plan_status=$($plan_command 2>&1)
  local plan_ret_code=$?
  if [ $plan_ret_code -eq 1 ];
  then
    echo "TFApply: Failed to plan for terraform script with return error code ${plan_ret_code}. TF_BASE=${TF_BASE}"
    echo "${plan_status}"
    return -5
  fi
  if [ $plan_ret_code -eq 0 ];
  then
    rm "${TF_PLAN}"
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
      return -6
    fi
  fi
  
}


function TFGetConfig {
  if [[ "${1}" == "" ]] || [[ "${2}" == "" ]];
  then
    echo 'TFGetConfig <Scope> <Key name> [<TF_HOME:'" ${TF_DEFAULT_HOME}"'>]' 
    return -1
  fi
  local TF_SCOPE="${1}"
  local TF_KEY_NAME="${2}"
  local TF_HOME="${3:-$TF_DEFAULT_HOME}"
  local TF_BASE="${TF_HOME}/${TF_SCOPE}_terraform"

  if [ ! -d "${TF_BASE}" ];
  then
    echo "TFGetConfig: Failed to return config due to missing terraform directory ${TF_BASE}"
    return -2
  fi
  local output_status
  output_status=$(terraform -chdir="${TF_BASE}" output "${TF_KEY_NAME}" 2>&1)
  output_ret_code=$?
  if [ $output_ret_code -ne 0 ];
  then
    echo "TFGetConfig: Failed to retrieve the property ${TF_KEY_NAME} from terraform directory ${TF_BASE}"
    echo "${output_status}"
    return -3
  fi
  output_value=$(echo "${output_status}" | cut -f 2 -d '"')
  echo "${output_value}"
}


