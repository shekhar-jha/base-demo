SCRIPT_DEFAULT_HOME=$(cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}" )" &> /dev/null && pwd)
INFRA_DEFAULT_HOME=$(pwd)

. "${SCRIPT_DEFAULT_HOME}"/basic.sh

function InfraApply {
  if [ "${1}" == "" ] || [ "${2}" == "" ];
  then
    echo 'InfraApply <Scope> <Infra config type: Terraform> [<Target: name of specific resource>] [<INFRA_HOME:'" ${INFRA_DEFAULT_HOME}"'>]' 
    return -1
  fi
  local INFRA_SCOPE="${1}"
  local INFRA_TYPE="${2}"
  local INFRA_TARGET="${3}"
  local INFRA_HOME="${4:-$INFRA_DEFAULT_HOME}"
  case "${INFRA_TYPE}" in

    't'|'T'|'Terraform'|'terraform')
      . "${SCRIPT_DEFAULT_HOME}/tf.sh"
      IsAvailable f TFApply "Terraform apply (TFApply) function"
      local tfapply_status 
      tfapply_status=$(TFApply "${INFRA_SCOPE}" 'Update' "${INFRA_TARGET}" "${INFRA_HOME}")
      local tfapply_ret_code=$? 
      if [ $tfapply_ret_code -ne 0 ]; 
      then
        echo "InfraApply: Failed to apply infrastructure using terraform due to error ${tfapply_ret_code}"
        echo "${tfapply_status}" 
        return -2 
      fi
      ;;

    *)
      echo "InfraApply: Only terraform infra type is currently supported."
      exit
      ;;
  esac
} 

function InfraGetConfig {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ];
  then
    echo 'InfraGetConfig <Scope> <Key Name> <Infra config type: Terraform> [<INFRA_HOME:'" ${INFRA_DEFAULT_HOME}"'>]' 
    return -1
  fi
  local INFRA_SCOPE="${1}"
  local INFRA_KEY="${2}"
  local INFRA_TYPE="${3}"
  local INFRA_HOME="${4:-$INFRA_DEFAULT_HOME}"
  case "${INFRA_TYPE}" in

    t|T|Terraform|terraform)
      . "${SCRIPT_DEFAULT_HOME}/tf.sh"
      IsAvailable f TFGetConfig "Terraform get config (TFGetConfig) function"
      local tfgetConfig_status 
      tfgetConfig_status=$(TFGetConfig "${INFRA_SCOPE}" "${INFRA_KEY}" "${INFRA_HOME}")
      local tfgetConfig_ret_code=$? 
      if [ $tfgetConfig_ret_code -ne 0 ]; 
      then
        echo "InfraGetConfig: Failed to get attribute ${INFRA_KEY} from terraform due to error ${tfgetConfig_ret_code}"
        echo "${tfgetConfig_status}" 
        return -2 
      fi
      ;;

    *)
      echo "InfraApply: Only terraform infra type is currently supported."
      exit
      ;;
  esac

}