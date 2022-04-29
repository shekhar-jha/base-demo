SCRIPT_DEFAULT_HOME=$(cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}" )" &> /dev/null && pwd)
INFRA_DEFAULT_HOME=$(pwd)

. "${SCRIPT_DEFAULT_HOME}"/basic.sh

function InfraInit {
  if [ "${1}" == "" ] || [ "${2}" == "" ];
  then
    echo 'InfraInit <Scope> <Infra config type: Terraform> [<Key backend: AWS>] [<INFRA_HOME:'" ${INFRA_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${5:-Exit}" "${6:-1}" "1"; return $?
  fi
  local INFRA_SCOPE="${1}"
  local INFRA_TYPE="${2}"
  local INFRA_KEY_BACKEND_TYPE="${3}"
  local INFRA_HOME="${4:-$INFRA_DEFAULT_HOME}"
  local INFRA_BASE
  echo "Initializing ${INFRA_CONFIG_TYPE} state for ${INFRA_SCOPE}..."
  case "${INFRA_TYPE}" in
    't'|'T'|'Terraform'|'terraform')
      . "${SCRIPT_DEFAULT_HOME}/tf.sh"
      IsAvailable f TFInit "Terraform init (TFInit) function"
      INFRA_BASE=$(TFHome "${INFRA_SCOPE}")
      local tfInit_status
      tfInit_status=$(TFInit "${INFRA_SCOPE}" "${INFRA_HOME}" 'r')
      local tfInit_ret_code=$?
      if [[ $tfInit_ret_code -ne 0 ]];
      then
        echo "InfraInit: Failed to initialize terraform as a code with error code ${tfInit_ret_code}"
        echo "${tfInit_status}"
        ReturnOrExit "${5:-Exit}" "${6:-1}" "2"; return $?
      else
        echo "${tfInit_status}"
      fi
      ;;

    *)
      echo "InfraInit: Only terraform infra type is currently supported."
      ReturnOrExit "${5:-Exit}" "${6:-1}" "3"; return $?
      ;;

  esac
  if [[ "${INFRA_KEY_BACKEND_TYPE}" != "" ]];
  then
    . "${SCRIPT_DEFAULT_HOME}/pgp.sh"
    IsAvailable f PGPGetKeyIfNotExists "PGPGetKeyIfNotExists function"
    PGPGetKeyIfNotExists "${INFRA_SCOPE}" 'PUB' "${INFRA_KEY_BACKEND_TYPE}" "${INFRA_BASE}"
  fi
  echo "Initialized ${INFRA_CONFIG_TYPE} state for ${INFRA_SCOPE}."
}

function InfraApply {
  if [ "${1}" == "" ] || [ "${2}" == "" ];
  then
    echo 'InfraApply <Scope> <Infra config type: Terraform> [<Operation: Update*|Destroy|Replace] [<Target: name of specific resource>] [<INFRA_HOME:'" ${INFRA_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${6:-Exit}" "${7:-1}" "1"; return $?
  fi
  local RETURN_VALUE=0
  local INFRA_SCOPE="${1}"
  local INFRA_TYPE="${2}"
  local INFRA_OPS="${3:-Update}"
  local INFRA_TARGET="${4}"
  local INFRA_HOME="${5:-$INFRA_DEFAULT_HOME}"
  echo "Applying change to ${INFRA_TYPE} state for ${INFRA_SCOPE}..."
  case "${INFRA_TYPE}" in

    't'|'T'|'Terraform'|'terraform')
      . "${SCRIPT_DEFAULT_HOME}/tf.sh"
      IsAvailable f TFApply "Terraform apply (TFApply) function"
      local tfApply_status
      tfApply_status=$(TFApply "${INFRA_SCOPE}" "${INFRA_OPS}" "${INFRA_TARGET}" "${INFRA_HOME}" 2>&1)
      local tfApply_ret_code=$?
      if [ $tfApply_ret_code -eq 1 ];
      then
        RETURN_VALUE=1
        echo "${tfApply_status}"
      fi
      if [ $tfApply_ret_code -gt 1 ];
      then
        echo "InfraApply: Failed to apply infrastructure using terraform due to error ${tfApply_ret_code}"
        echo "${tfApply_status}"
        ReturnOrExit "${6:-Exit}" "${7:-1}" "2"; return $?
      fi
      if [ $tfApply_ret_code -eq 0 ];
      then
        echo "${tfApply_status}"
      fi
      ;;

    *)
      echo "InfraApply: Only terraform infra type is currently supported."
      ReturnOrExit "${6:-Exit}" "${7:-1}" "3"; return $?
      ;;
  esac
  echo "Applied change to ${INFRA_TYPE} state for ${INFRA_SCOPE}."
  return $RETURN_VALUE
} 

function InfraGetConfig {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ];
  then
    echo 'InfraGetConfig <Scope> <Key Name> <Infra config type: Terraform> [<Key backend: AWS>] [<INFRA_HOME:'" ${INFRA_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${6:-Exit}" "${7:-1}" "1"; return $?
  fi
  local INFRA_SCOPE="${1}"
  local INFRA_KEY="${2}"
  local INFRA_TYPE="${3}"
  local INFRA_KEY_BACKEND_TYPE="${4}"
  local INFRA_HOME="${5:-$INFRA_DEFAULT_HOME}"
  local INFRA_VALUE_OUTPUT
  case "${INFRA_TYPE}" in

    t|T|Terraform|terraform)
      . "${SCRIPT_DEFAULT_HOME}/tf.sh"
      IsAvailable f TFGetConfig "Terraform get config (TFGetConfig) function"
      local tfGetConfig_status
      tfGetConfig_status=$(TFGetConfig "${INFRA_SCOPE}" "${INFRA_KEY}" "${INFRA_HOME}")
      local tfGetConfig_ret_code=$?
      if [ $tfGetConfig_ret_code -ne 0 ];
      then
        echo "InfraGetConfig: Failed to get attribute ${INFRA_KEY} from terraform due to error ${tfGetConfig_ret_code}"
        echo "${tfGetConfig_status}"
        ReturnOrExit "${6:-Exit}" "${7:-1}" "2"; return $?
      else
        INFRA_VALUE_OUTPUT="${tfGetConfig_status}"
      fi
      ;;

    *)
      echo "InfraGetConfig: Only terraform infra type is currently supported."
      ReturnOrExit "${6:-Exit}" "${7:-1}" "3"; return $?
      ;;
  esac
  if [[ "${INFRA_KEY_BACKEND_TYPE}" != "" ]];
  then
      IsAvailable c base64 "Base64 decoder"
      . "${SCRIPT_DEFAULT_HOME}/pgp.sh"
      IsAvailable f PGPGetKeyIfNotExists "PGPGetKeyIfNotExists function"
      local ignoreValue=$(PGPGetKeyIfNotExists "${INFRA_SCOPE}" 'KEY' "${INFRA_KEY_BACKEND_TYPE}")
      echo "${INFRA_VALUE_OUTPUT}" |base64 -d | PGPDecrypt "${INFRA_SCOPE}"
      PGPDeleteKeyFile "${INFRA_SCOPE}" 'KEY'
  else
    echo "${INFRA_VALUE_OUTPUT}"
  fi
}

function InfraSaveState {
    if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ];
    then
      echo 'InfraSaveState <Scope> <Infra config type: Terraform> <State backend: AWS> <Key backend: AWS> [<State store location: bucket in AWS>] [<INFRA_HOME:'" ${INFRA_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
      ReturnOrExit "${7:-Exit}" "${8:-1}" "1"; return $?
    fi
    local INFRA_SCOPE="${1}"
    local INFRA_CONFIG_TYPE="${2}"
    local INFRA_STATE_BACKEND_TYPE="${3}"
    local INFRA_KEY_BACKEND_TYPE="${4}"
    local INFRA_STATE_STORE_NAME="${5}"
    local INFRA_HOME="${5:-$INFRA_DEFAULT_HOME}"
    local INFRA_STATE_FILE_NAME
    local INFRA_STATE_FILE_PATH
    local INFRA_BASE
    echo "Saving ${INFRA_CONFIG_TYPE} state for ${INFRA_SCOPE} to ${INFRA_STATE_STORE_NAME} on ${INFRA_STATE_STORE_NAME}"
    echo "Cleaning up key files..."
    case "${INFRA_CONFIG_TYPE}" in
      t|T|Terraform|terraform)
        . "${SCRIPT_DEFAULT_HOME}/tf.sh"
        IsAvailable f TFStatePack "Terraform pack state (TFStatePack) function"
        IsAvailable f TFStatePackFileName "TFStatePackFileName function"
        IsAvailable f TFStatePackFilePath "TFStatePackFilePath function"
        INFRA_STATE_FILE_NAME=$(TFStatePackFileName "${INFRA_SCOPE}")
        INFRA_STATE_FILE_PATH=$(TFStatePackFilePath "${INFRA_SCOPE}")
        INFRA_BASE=$(TFHome "${INFRA_SCOPE}")
        . "${SCRIPT_DEFAULT_HOME}/pgp.sh"
        IsAvailable f PGPDeleteKeyFile "PGPDeleteKeyFile function"
        PGPDeleteKeyFile "${INFRA_SCOPE}" 'PUB' "${INFRA_BASE}"
        TFStatePack "${INFRA_SCOPE}"
        pack_ret_code=$?
        if [[ $pack_ret_code -ne 0 ]];
        then
          echo "InfraSaveState: Failed to pack terraform state files due to error ${pack_ret_code}"
          ReturnOrExit "${7:-Exit}" "${8:-1}" "2"; return $?
        fi
        ;;

      *)
        echo "InfraSaveState: Only Terraform infra config type is currently supported."
        ReturnOrExit "${7:-Exit}" "${8:-1}" "3"; return $?
        ;;
    esac
    if [[ ! -f ${INFRA_STATE_FILE_PATH} ]];
    then
      echo "InfraSaveState: The state file ${INFRA_STATE_FILE_PATH} does not exist."
      ReturnOrExit "${7:-Exit}" "${8:-1}" "4"; return $?
    fi
    . "${SCRIPT_DEFAULT_HOME}/pgp.sh"
    IsAvailable f PGPGetKeyIfNotExists "PGPGetKeyIfNotExists function"
    IsAvailable f PGPEncrypt "PGPEncrypt function"
    PGPGetKeyIfNotExists "${INFRA_SCOPE}" 'PUB' "${INFRA_KEY_BACKEND_TYPE}"
    PGPEncrypt "${INFRA_SCOPE}" "${INFRA_STATE_FILE_PATH}"; encrypt_ret_code=$?
    if [[ $encrypt_ret_code -ne 0 ]];
    then
      echo "InfraSaveState: Failed to encrypt state file ${INFRA_STATE_FILE_NAME} due to error ${encrypt_ret_code}"
      ReturnOrExit "${7:-Exit}" "${8:-1}" "5"; return $?
    fi
    IsAvailable f PGPGetEncryptedFileName "PGPGetEncryptedFileName function"
    local INFRA_STATE_ENCRYPTED_FILE_PATH
    INFRA_STATE_ENCRYPTED_FILE_PATH=$(PGPGetEncryptedFileName "${INFRA_SCOPE}" "${INFRA_STATE_FILE_PATH}")
    if [[ ! -f "${INFRA_STATE_ENCRYPTED_FILE_PATH}" ]];
    then
      echo "InfraSaveState: Encrypted state file is not available at ${INFRA_STATE_ENCRYPTED_FILE_PATH}"
      PGPDeleteKeyFile "${INFRA_SCOPE}" 'PUB'
      ReturnOrExit "${7:-Exit}" "${8:-1}" "6"; return $?
    else
      PGPDeleteKeyFile "${INFRA_SCOPE}" 'PUB'
    fi
    local INFRA_STORE_FILE_NAME
    case "${INFRA_STATE_BACKEND_TYPE}" in

      AWS)
        if [[ "${INFRA_STATE_STORE_NAME}" == "" ]];
        then
          echo "InfraSaveState: Failed to save state since the name of state bucket is not available."
          ReturnOrExit "${7:-Exit}" "${8:-1}" "7"; return $?
        fi
        INFRA_STORE_FILE_NAME="${INFRA_STATE_STORE_NAME}/${INFRA_STATE_FILE_NAME}"
        ;;

      *)
        echo "InfraSaveState: Only AWS backend is currently supported."
        ReturnOrExit "${7:-Exit}" "${8:-1}" "8"; return $?
        ;;
    esac
    . "${SCRIPT_DEFAULT_HOME}/store.sh"
    IsAvailable f StoreFile "Store file (StoreFile) function"
    StoreFile "${INFRA_SCOPE}" "${INFRA_STATE_BACKEND_TYPE}" "${INFRA_STATE_ENCRYPTED_FILE_PATH}" "${INFRA_STORE_FILE_NAME}"
    local store_file_ret_code=$?
    if [[ $store_file_ret_code -ne 0 ]];
    then
      echo "InfraSaveState: Failed to store infra state due to error ${store_file_ret_code}"
      ReturnOrExit "${7:-Exit}" "${8:-1}" "9"; return $?
    fi
    echo "Deleting the state file ${INFRA_STORE_FILE_NAME} present at ${INFRA_STATE_ENCRYPTED_FILE_PATH}"
    rm -rf "${INFRA_STATE_ENCRYPTED_FILE_PATH}"
    echo "Saved ${INFRA_CONFIG_TYPE} state for ${INFRA_SCOPE} to ${INFRA_STATE_STORE_NAME} on ${INFRA_STATE_STORE_NAME}"
}


function InfraLoadState {
    if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ];
    then
      echo 'InfraLoadState <Scope> <Infra config type: Terraform> <State backend: AWS> <Key backend: AWS> [<State store location: bucket in AWS>] [<INFRA_HOME:'" ${INFRA_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
      ReturnOrExit "${7:-Exit}" "${8:-1}" "1"; return $?
    fi
    local INFRA_SCOPE="${1}"
    local INFRA_CONFIG_TYPE="${2}"
    local INFRA_STATE_BACKEND_TYPE="${3}"
    local INFRA_KEY_BACKEND_TYPE="${4}"
    local INFRA_STATE_STORE_NAME="${5}"
    local INFRA_HOME="${5:-$INFRA_DEFAULT_HOME}"
    local INFRA_STATE_FILE_NAME
    local INFRA_STATE_FILE_PATH
    echo "Loading ${INFRA_CONFIG_TYPE} state for ${INFRA_SCOPE} from ${INFRA_STATE_STORE_NAME} on ${INFRA_STATE_BACKEND_TYPE}"
    case "${INFRA_CONFIG_TYPE}" in
      t|T|Terraform|terraform)
        . "${SCRIPT_DEFAULT_HOME}/tf.sh"
        IsAvailable f TFStatePackFileName "TFStatePackFileName function"
        IsAvailable f TFStatePackFilePath "TFStatePackFilePath function"
        INFRA_STATE_FILE_NAME=$(TFStatePackFileName "${INFRA_SCOPE}")
        INFRA_STATE_FILE_PATH=$(TFStatePackFilePath "${INFRA_SCOPE}")
        ;;

      *)
        echo "InfraLoadState: Only Terraform infra config type is currently supported."
        ReturnOrExit "${7:-Exit}" "${8:-1}" "3"; return $?
        ;;
    esac
    local INFRA_STORE_FILE_NAME
    case "${INFRA_STATE_BACKEND_TYPE}" in

      AWS)
        if [[ "${INFRA_STATE_STORE_NAME}" == "" ]];
        then
          echo "InfraLoadState: Failed to load state since the name of state bucket is not available."
          ReturnOrExit "${7:-Exit}" "${8:-1}" "7"; return $?
        fi
        INFRA_STORE_FILE_NAME="${INFRA_STATE_STORE_NAME}/${INFRA_STATE_FILE_NAME}"
        ;;

      *)
        echo "InfraLoadState: Only AWS backend is currently supported."
        ReturnOrExit "${7:-Exit}" "${8:-1}" "8"; return $?
        ;;
    esac
    . "${SCRIPT_DEFAULT_HOME}/pgp.sh"
    IsAvailable f PGPGetEncryptedFileName "PGPGetEncryptedFileName function"
    local INFRA_STATE_ENCRYPTED_FILE_PATH
    INFRA_STATE_ENCRYPTED_FILE_PATH=$(PGPGetEncryptedFileName "${INFRA_SCOPE}" "${INFRA_STATE_FILE_PATH}")
    . "${SCRIPT_DEFAULT_HOME}/store.sh"
    IsAvailable f GetStoredFile "Get file (GetStoredFile) function"
    GetStoredFile "${INFRA_SCOPE}" "${INFRA_STATE_BACKEND_TYPE}" "${INFRA_STORE_FILE_NAME}" "${INFRA_STATE_ENCRYPTED_FILE_PATH}"
    local get_file_ret_code=$?
    if [[ $get_file_ret_code -ne 0 ]];
    then
      echo "InfraLoadState: Failed to load infra state from store due to error ${get_file_ret_code}"
      ReturnOrExit "${7:-Exit}" "${8:-1}" "9"; return $?
    fi
    if [[ ! -f ${INFRA_STATE_ENCRYPTED_FILE_PATH} ]];
    then
      echo "InfraLoadState: The encrypted state file ${INFRA_STATE_ENCRYPTED_FILE_PATH} does not exist."
      ReturnOrExit "${7:-Exit}" "${8:-1}" "4"; return $?
    fi
    IsAvailable f PGPGetKeyIfNotExists "PGPGetKeyIfNotExists function"
    IsAvailable f PGPDecrypt "PGPDecrypt function"
    PGPGetKeyIfNotExists "${INFRA_SCOPE}" 'KEY' "${INFRA_KEY_BACKEND_TYPE}"
    PGPDecrypt "${INFRA_SCOPE}" "${INFRA_STATE_FILE_PATH}"; decrypt_ret_code=$?
    if [[ $decrypt_ret_code -ne 0 ]];
    then
      echo "InfraLoadState: Failed to decrypt state file ${INFRA_STATE_ENCRYPTED_FILE_PATH} due to error ${decrypt_ret_code}"
      ReturnOrExit "${7:-Exit}" "${8:-1}" "5"; return $?
    fi
    if [[ ! -f "${INFRA_STATE_FILE_PATH}" ]];
    then
      echo "InfraLoadState: Decrypted state file is not available at ${INFRA_STATE_FILE_PATH}"
      PGPDeleteKeyFile "${INFRA_SCOPE}" 'KEY'
      ReturnOrExit "${7:-Exit}" "${8:-1}" "6"; return $?
    else
      PGPDeleteKeyFile "${INFRA_SCOPE}" 'KEY'
    fi
    case "${INFRA_CONFIG_TYPE}" in
      t|T|Terraform|terraform)
        IsAvailable f TFStateUnPack "Terraform unpack state (TFStateUnPack) function"
        TFStateUnPack "${INFRA_SCOPE}"
        unpack_ret_code=$?
        if [[ $unpack_ret_code -ne 0 ]];
        then
          echo "InfraLoadState: Failed to unpack terraform state file due to error ${unpack_ret_code}"
          ReturnOrExit "${7:-Exit}" "${8:-1}" "2"; return $?
        fi
        ;;

      *)
        echo "InfraLoadState: Only Terraform infra config type is currently supported."
        ReturnOrExit "${7:-Exit}" "${8:-1}" "3"; return $?
        ;;
    esac
    echo "Loaded ${INFRA_CONFIG_TYPE} state for ${INFRA_SCOPE} from ${INFRA_STATE_STORE_NAME} on ${INFRA_STATE_STORE_NAME}"
}

function InfraCleanup {
  if [ "${1}" == "" ] || [ "${2}" == "" ];
  then
    echo 'InfraCleanup <Scope> <Infra config type: Terraform> [<Key backend: AWS>] [<INFRA_HOME:'" ${INFRA_DEFAULT_HOME}"'>] [<Return: Exit*|Return>] [Exit code]'
    ReturnOrExit "${5:-Exit}" "${6:-1}" "1"; return $?
  fi
  local INFRA_SCOPE="${1}"
  local INFRA_TYPE="${2}"
  local INFRA_KEY_BACKEND_TYPE="${3}"
  local INFRA_HOME="${4:-$INFRA_DEFAULT_HOME}"
  echo "Cleaning up ${INFRA_TYPE} state for ${INFRA_SCOPE}..."
  case "${INFRA_TYPE}" in
    't'|'T'|'Terraform'|'terraform')
      . "${SCRIPT_DEFAULT_HOME}/tf.sh"
      IsAvailable f TFCleanup "TFCleanup function"
      local tfCleanup_status
      tfCleanup_status=$(TFCleanup "${INFRA_SCOPE}" "${INFRA_HOME}" 'r')
      local tfCleanup_ret_code=$?
      if [[ $tfCleanup_ret_code -ne 0 ]];
      then
        echo "InfraCleanup: Failed to cleanup terraform as a code with error code ${tfCleanup_ret_code}"
        echo "${tfCleanup_status}"
        ReturnOrExit "${5:-Exit}" "${6:-1}" "2"; return $?
      else
        echo "${tfCleanup_status}"
      fi
      ;;

    *)
      echo "InfraCleanup: Only terraform infra type is currently supported."
      ReturnOrExit "${5:-Exit}" "${6:-1}" "3"; return $?
      ;;

  esac
  echo "Cleaned up ${INFRA_TYPE} state for ${INFRA_SCOPE}."
}