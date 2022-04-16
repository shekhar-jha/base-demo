
SCRIPT_DEFAULT_HOME=$(cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}" )" &> /dev/null && pwd)
PGP_DEFAULT_HOME=$(pwd)
PGP_DEFAULT_KEY_NAME_SUFFIX="${PGP_KEY_NAME_SUFFIX:-tf-gpg-key}"
PGP_DEFAULT_PUB_NAME_SUFFIX="${PGP_PUB_NAME_SUFFIX:-tf-gpg-pub}"
PGP_DEFAULT_KEY_FILE_SUFFIX="key"
PGP_DEFAULT_PUB_FILE_SUFFIX="pub"
PGP_DEFAULT_OUT_FILE_SUFFIX="out"

. "${SCRIPT_DEFAULT_HOME}"/basic.sh

IsAvailable Command gpg "GNU PGP" 
IsAvailable Command base64 "Base64"

function PGPKeyName {
  if [ "${1}" == "" ] || [ "${2}" == "" ];
  then
    echo 'PGPKeyFileExists <SCOPE> <Type: KEY|PUB>'
    return -1
  fi
  local PGP_SCOPE="${1}"
  local PGP_TYPE="${2}"
  if [ "${PGP_SCOPE}" == "" ];
  then
    return -3
  fi
  case $PGP_TYPE in 
    KEY)
      local PGP_KEY_NAME
      PGP_KEY_NAME="${PGP_SCOPE}-${PGP_DEFAULT_KEY_NAME_SUFFIX}"
      ;;

    PUB)  
      local PGP_KEY_NAME 
      PGP_KEY_NAME="${PGP_SCOPE}-${PGP_DEFAULT_PUB_NAME_SUFFIX}"
      ;;

    *)
      return -2
      ;;
  esac
  echo "${PGP_KEY_NAME}"
  return 0
}

function PGPKeyFileExists {
  if [ "${1}" == "" ] || [ "${2}" == "" ];
  then
    echo 'PGPKeyFileExists <SCOPE> <Type: KEY|PUB> [<PGP_HOME:'" ${PGP_DEFAULT_HOME}"'}>]' 
    return -1
  fi
  local PGP_SCOPE="${1}"
  local PGP_TYPE="${2}"
  local PGP_HOME="${3:-$PGP_DEFAULT_HOME}"
  case $PGP_TYPE in 
    KEY)
      local PGP_KEY_NAME
      PGP_KEY_NAME=$(PGPKeyName "${PGP_SCOPE}" "KEY")
      local PGP_FILE_KEY="${PGP_KEY_NAME}.key"
      ;;
    
    PUB)  
      local PGP_KEY_NAME
      PGP_KEY_NAME=$(PGPKeyName "${PGP_SCOPE}" "PUB")
      local PGP_FILE_KEY="${PGP_KEY_NAME}.${PGP_DEFAULT_PUB_FILE_SUFFIX}"
      ;;
    
    *)
      echo "PGPKeyFileExists: Only type PUB & KEY are supported at this time"
      return -3
      ;;
  esac  
  local PGP_PATH_KEY="${PGP_HOME}/${PGP_FILE_KEY}"
  if [ ! -f "${PGP_PATH_KEY}" ];
  then
    # echo "PGPKeyFileExists: Expected PGP key file at location ${PGP_PATH_KEY}"
    return 1
  fi  
}

function PGPDeleteKeyFile {
  if [ "${1}" == "" ] || [ "${2}" == "" ];
  then
    echo 'PGPDeleteKeyFile <SCOPE> <Type: KEY|PUB> [<PGP_HOME:'" ${PGP_DEFAULT_HOME}"'>]' 
    return -1
  fi
  local PGP_SCOPE="${1}"
  local PGP_TYPE="${2}"
  local PGP_HOME="${3:-$PGP_DEFAULT_HOME}"
  case $PGP_TYPE in 
    KEY)
      local PGP_KEY_NAME 
      PGP_KEY_NAME=$(PGPKeyName "${PGP_SCOPE}" "KEY")
      local PGP_FILE_KEY="${PGP_KEY_NAME}.${PGP_DEFAULT_KEY_FILE_SUFFIX}"
      ;;
    
    PUB)  
      local PGP_KEY_NAME 
      PGP_KEY_NAME=$(PGPKeyName "${PGP_SCOPE}" "PUB")
      local PGP_FILE_KEY="${PGP_KEY_NAME}.${PGP_DEFAULT_PUB_FILE_SUFFIX}"
      ;;
    
    *)
      echo "PGPDeleteKeyFile: Only type PUB & KEY are supported at this time"
      return -3
      ;;
  esac  
  local PGP_PATH_KEY="${PGP_HOME}/${PGP_FILE_KEY}"
  if [ ! -f "${PGP_PATH_KEY}" ];
  then
    echo "PGPDeleteKeyFile: Expected PGP key file at location ${PGP_PATH_KEY}"
    return 1
  fi
  local rm_status
  rm_status=$(rm -f "${PGP_PATH_KEY}")
  rm_ret_code=$?
  if [ $rm_ret_code -ne 0 ];
  then
    echo "PGPDeleteKeyFile: Failed to delete key file ${PGP_PATH_KEY} due to error ${rm_ret_code}"
    echo "$rm_status"
    exit -2
  fi
}

function PGPCreateKeys {
  if [[ "${1}" == "" ]];
  then
    echo 'CreatePGPKeys <Scope> [<PGP_HOME:'" ${PGP_DEFAULT_HOME}"'>] [<Email: nobody@example.com>] [<Key-Type: RSA>] [<Key-Length: 4096>] [<Expiration: 0>]'
    return -1
  fi
  local PGP_SCOPE=${1}
  local PGP_HOME="${2:-$PGP_DEFAULT_HOME}"
  local PGP_EMAIL="${3:-nobody@example.com}"
  local PGP_KEY_TYPE="${4:-RSA}"
  local PGP_KEY_LENGTH="${5:-4096}"
  local PGP_KEY_EXPIRE="${6:-0}"
  local PGP_PATH_HOME_DIR="${PGP_HOME}/.gpg"
  local PGP_KEY_NAME
  PGP_KEY_NAME=$(PGPKeyName "${PGP_SCOPE}" "KEY")
  local PGP_PUB_NAME 
  PGP_PUB_NAME=$(PGPKeyName "${PGP_SCOPE}" 'PUB')
  local PGP_FILE_KEY="${PGP_KEY_NAME}.${PGP_DEFAULT_KEY_FILE_SUFFIX}"
  local PGP_FILE_PUB="${PGP_PUB_NAME}.${PGP_DEFAULT_PUB_FILE_SUFFIX}"
  local PGP_PATH_KEY="${PGP_HOME}/${PGP_FILE_KEY}"
  local PGP_PATH_PUB="${PGP_HOME}/${PGP_FILE_PUB}"
  local PGP_PATH_KEY_TEMPL="${PGP_PATH_HOME_DIR}/${PGP_SCOPE}-gpg.tmpl"
  
  echo "Generating PGP keys...."
  mkdir -p "${PGP_PATH_HOME_DIR}"
  chmod 700 "${PGP_PATH_HOME_DIR}"
  cat << EOF > "${PGP_PATH_KEY_TEMPL}"
%echo Generating a key for ${PGP_SCOPE}
Key-Type: ${PGP_KEY_TYPE}
Key-Length: ${PGP_KEY_LENGTH}
Subkey-Type: ${PGP_KEY_TYPE}
Subkey-Length: ${PGP_KEY_LENGTH}
Name-Real: ${PGP_SCOPE} Infrastructure Key
Name-Comment: Encryption Key for ${PGP_SCOPE}
Name-Email: ${PGP_EMAIL}
Expire-Date: ${PGP_KEY_EXPIRE}
%no-ask-passphrase
%no-protection
%commit
%echo done
EOF
  gpg --batch --homedir "${PGP_PATH_HOME_DIR}" --generate-key "${PGP_PATH_KEY_TEMPL}"
  rm -rf "${PGP_PATH_KEY_TEMPL}"
  gpg --homedir "${PGP_PATH_HOME_DIR}" --export "${PGP_EMAIL}" > "${PGP_PATH_PUB}"
  gpg --homedir "${PGP_PATH_HOME_DIR}" --export-secret-key "${PGP_EMAIL}" > "${PGP_PATH_KEY}"
  rm -rf "${PGP_PATH_HOME_DIR}"
  echo "Generated PGP keys"
}

function PGPKeyExistsInStore {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ];
  then
    echo 'PGPKeyExistsInStore <SCOPE> <Type: KEY|PUB> <Store type: AWS|GCP>' 
    return -1
  fi
  local PGP_SCOPE="${1}"
  local PGP_TYPE="${2}"
  local PGP_STORE_TYPE="${3}"
  case $PGP_TYPE in 
    KEY)
      local PGP_KEY_NAME
      PGP_KEY_NAME=$(PGPKeyName "${PGP_SCOPE}" "KEY")
      ;;
    
    PUB)  
      local PGP_KEY_NAME
      PGP_KEY_NAME=$(PGPKeyName "${PGP_SCOPE}" "PUB")
      ;;
    
    *)
      echo 'PGPKeyExistsInStore: Only type PUB & KEY are supported at this time'
      return -2
      ;;
  esac  
  . "${SCRIPT_DEFAULT_HOME}"/store.sh
  IsAvailable f "StoreKeyExists" "StoreKeyExists function"
  StoreKeyExists "${PGP_SCOPE}" "${PGP_STORE_TYPE}" "${PGP_KEY_NAME}"
  local store_key_exists_ret_code=$?
  if [ $store_key_exists_ret_code -eq 0 ]
  then
    echo "PGP key ${PGP_KEY_NAME} exists in store."
  else
    if [ $store_key_exists_ret_code -eq 1 ]
    then
      echo "PGP key ${PGP_KEY_NAME} does not exists in store"
      return 1
    else
      echo "Failed to locate PGP key ${PGP_KEY_NAME} in store"
      return -3
    fi
  fi
}

function PGPStoreKeys {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ];
  then
    echo 'PGPStoreKeys <SCOPE> <Type: KEY|PUB> <Store type: AWS|GCP> [<PGP_HOME:'" ${PGP_DEFAULT_HOME}"'>]'    

    return -1
  fi
  local PGP_SCOPE="${1}"
  local PGP_TYPE="${2}"
  local PGP_STORE_TYPE="${3}"
  local PGP_HOME="${4:-$PGP_DEFAULT_HOME}"
  case $PGP_TYPE in 
    KEY)
      local PGP_KEY_NAME
      PGP_KEY_NAME=$(PGPKeyName "${PGP_SCOPE}" "KEY")
      local PGP_FILE_KEY="${PGP_KEY_NAME}.${PGP_DEFAULT_KEY_FILE_SUFFIX}"
      local PGP_PATH_KEY="${PGP_HOME}/${PGP_FILE_KEY}"
      ;;
    
    PUB)  
      local PGP_KEY_NAME
      PGP_KEY_NAME=$(PGPKeyName "${PGP_SCOPE}" "PUB")
      local PGP_FILE_KEY="${PGP_KEY_NAME}.${PGP_DEFAULT_PUB_FILE_SUFFIX}"
      local PGP_PATH_KEY="${PGP_HOME}/${PGP_FILE_KEY}"
      ;;
    
    *)
      echo 'PGPStoreKeys: Only type PUB & KEY are supported at this time'
      return -3
      ;;
  esac  
  if [ ! -f "${PGP_PATH_KEY}" ];
  then
    echo "PGPStoreKeys: Expected PGP key file at location ${PGP_PATH_KEY}"
    return -2
  fi
  echo "PGPStoreKeys: Storing key ${PGP_KEY_NAME}...."
  . "${SCRIPT_DEFAULT_HOME}"/store.sh
  IsAvailable f "StoreKey" "StoreKey function"
  StoreKey "${PGP_SCOPE}" "${PGP_STORE_TYPE}" "${PGP_KEY_NAME}" "${PGP_PATH_KEY}"
  local store_key_ret_code=$?
  if [ $store_key_ret_code -eq 0 ];
  then
    echo "PGPStoreKeys: Stored key ${PGP_KEY_NAME} successfully."
  else
    echo "PGPStoreKeys: Storing key ${PGP_KEY_NAME} failed with error ${store_key_ret_code}"
    return -4
  fi
  return 0
}

function PGPGetKey {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ];
  then
    echo 'PGPGetKey <SCOPE> <Type: KEY|PUB> <Store type: AWS|GCP> [<PGP_HOME:'" ${PGP_DEFAULT_HOME}"'>]'    

    return -1
  fi
  local PGP_SCOPE="${1}"
  local PGP_TYPE="${2}"
  local PGP_STORE_TYPE="${3}"
  local PGP_HOME="${4:-$PGP_DEFAULT_HOME}"
  case $PGP_TYPE in 
    KEY)
      local PGP_KEY_NAME
      PGP_KEY_NAME=$(PGPKeyName "${PGP_SCOPE}" "KEY")
      local PGP_FILE_KEY="${PGP_KEY_NAME}.${PGP_DEFAULT_KEY_FILE_SUFFIX}"
      ;;
    
    PUB)  
      local PGP_KEY_NAME
      PGP_KEY_NAME=$(PGPKeyName "${PGP_SCOPE}" "PUB")
      local PGP_FILE_KEY="${PGP_KEY_NAME}.${PGP_DEFAULT_PUB_FILE_SUFFIX}"
      ;;
    
    *)
      echo 'PGPGetKey: Only type PUB & KEY are supported at this time'
      return -3
      ;;
  esac  
  local PGP_PATH_KEY="${PGP_HOME}/${PGP_FILE_KEY}"
  . "${SCRIPT_DEFAULT_HOME}"/store.sh
  IsAvailable f "GetStoredKey" "GetStoredKey function"
  local get_key_status
  get_key_status=$(GetStoredKey "${PGP_SCOPE}" "${PGP_STORE_TYPE}" "${PGP_KEY_NAME}" "${PGP_PATH_KEY}" F)
  local get_key_ret_code=$?
  if [ $get_key_ret_code -eq 0 ] && [ -f ${PGP_PATH_KEY} ];
  then
    base64 -D < "${PGP_PATH_KEY}" > "${PGP_PATH_KEY}.tmp"
    mv "${PGP_PATH_KEY}.tmp" "${PGP_PATH_KEY}"
    echo "PGPStoreKeys: Stored key ${PGP_KEY_NAME} retrieved and saved at ${PGP_PATH_KEY} successfully."
  else
    echo "PGPStoreKeys: Retrieving key ${PGP_KEY_NAME} failed with error ${get_key_ret_code}"
    echo "$get_key_status"
    return -4
  fi
  return 0
}

function PGPGetKeyIfNotExists {
  if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ];
  then
    echo 'PGPGetKeyIfNotExists <SCOPE> <Type: KEY|PUB> <Store type: AWS|GCP> [<PGP_HOME:'" ${PGP_DEFAULT_HOME}"'>] [<Exit on failure: Yes*|No>]'
    return -1
  fi
  local exitOnFailure="${5:-Yes}"
  local key_file_exists
  PGPKeyFileExists "${1}" "${2}" "${4}"; key_file_exists=$?
  if [ $key_file_exists -eq 1 ];
  then
    PGPGetKey "${1}" "${2}" ${3} "${4}"; key_get_key=$?
    if [ $key_get_key -ne 0 ];
    then
      echo "PGPGetKeyIfNotExists: Failed to get key due to error ${$key_get_key}"
      case "${exitOnFailure}" in
        n|N|no|No)
          return -2
          ;;
        yes|Yes|y|*)
          exit
          ;;
      esac
    fi
  fi
}

function PGPDecrypt {
  if [[ "${1}" == "" ]];
  then
    echo "PGPDecrypt <Scope> [<File name without $
    }{PGP_DEFAULT_OUT_FILE_SUFFIX}>] [<PGP_HOME: ${PGP_DEFAULT_HOME}>]"
    return -1
  fi
  local PGP_SCOPE=${1}
  local PGP_FILE=${2}
  local PGP_HOME="${3:-$PGP_DEFAULT_HOME}"
  local PGP_FILE_OUT="${PGP_FILE}.${PGP_DEFAULT_OUT_FILE_SUFFIX}"
  local PGP_PATH_HOME_DIR="${PGP_HOME}/.gpg"
  if [ ! -d "${PGP_PATH_HOME_DIR}" ];
  then
    mkdir -p "${PGP_PATH_HOME_DIR}"
    chmod 700 "${PGP_PATH_HOME_DIR}"
  fi
  local PGP_KEY_NAME
  PGP_KEY_NAME=$(PGPKeyName "${PGP_SCOPE}" "KEY")
  local PGP_FILE_KEY="${PGP_KEY_NAME}.${PGP_DEFAULT_KEY_FILE_SUFFIX}"
  local PGP_PATH_KEY="${PGP_HOME}/${PGP_FILE_KEY}"
  local import_key_status
  import_key_status=$(gpg --homedir "${PGP_PATH_HOME_DIR}" --import "${PGP_PATH_KEY}" 2>&1)
  import_key_ret_code=$?
  if [[ $import_key_ret_code -ne 0 ]];
  then
    echo "PGPDecrypt: Failed to import key to PGP store at ${PGP_PATH_HOME_DIR} due to error ${import_key_ret_code}"
    echo "${import_key_status}"
    rm -rf "${PGP_PATH_HOME_DIR}"
    return -2
  fi
  if [[ "${PGP_FILE}" != "" ]];
  then
    if [[ ! -f "${PGP_FILE_OUT}" ]];
    then
      echo "PGPDecrypt: Failed to decrypt file ${PGP_FILE_OUT} since it does not exist. Please ensure that you profile file name without the .${PGP_DEFAULT_OUT_FILE_SUFFIX} suffix."
      rm -rf "${PGP_PATH_HOME_DIR}"
      return -3
    fi
    local decrypt_status
    decrypt_status=$(gpg --homedir "${PGP_PATH_HOME_DIR}" -d -o "${PGP_FILE}" "${PGP_FILE_OUT}" 2>&1)
    local decrypt_ret_code=$?
    if [[ $decrypt_ret_code -ne 0 ]];
    then 
      echo "PGPDecrypt: Failed to decrypt file ${PGP_FILE_OUT} due to error ${decrypt_ret_code}"
      echo "${decrypt_status}"
      rm -rf "${PGP_PATH_HOME_DIR}"
      return -4
    fi
  else
    gpg --homedir "${PGP_PATH_HOME_DIR}" -d
    local decrypt_ret_code=$?
    if [[ $decrypt_ret_code -ne 0 ]];
    then
      echo "PGPDecrypt: Failed to decrypt input due to error ${decrypt_ret_code}"
      rm -rf "${PGP_PATH_HOME_DIR}"
      return -5 
    fi
  fi
  rm -rf "${PGP_PATH_HOME_DIR}"
}

function PGPEncrypt {
  if [[ "${1}" == "" ]];
  then
    echo 'PGPEncrypt <Scope> [<File>] [<PGP_HOME:'" ${PGP_DEFAULT_HOME}"'>]'
    return -1
  fi
  local PGP_SCOPE=${1}
  local PGP_FILE=${2}
  local PGP_HOME="${3:-$PGP_DEFAULT_HOME}"
  local PGP_FILE_OUT="${PGP_FILE}.${PGP_DEFAULT_OUT_FILE_SUFFIX}"
  local PGP_PATH_HOME_DIR="${PGP_HOME}/.gpg"
  if [ ! -d "${PGP_PATH_HOME_DIR}" ];
  then
    mkdir -p "${PGP_PATH_HOME_DIR}"
    chmod 700 "${PGP_PATH_HOME_DIR}"
  fi
  local PGP_PUB_NAME
  PGP_PUB_NAME=$(PGPKeyName "${PGP_SCOPE}" "PUB")
  local PGP_FILE_PUB="${PGP_PUB_NAME}.${PGP_DEFAULT_PUB_FILE_SUFFIX}"
  local PGP_PATH_PUB="${PGP_HOME}/${PGP_FILE_PUB}"
  local import_key_status
  import_key_status=$(gpg --homedir "${PGP_PATH_HOME_DIR}" --import "${PGP_PATH_PUB}" 2>&1)
  import_key_ret_code=$?
  if [[ $import_key_ret_code -ne 0 ]];
  then
    echo "PGPEncrypt: Failed to import key to PGP store at ${PGP_PATH_HOME_DIR} due to error ${import_key_ret_code}"
    echo "${import_key_status}"
    rm -rf "${PGP_PATH_HOME_DIR}"
    return -2
  fi
  if [[ "${PGP_FILE}" != "" ]];
  then
    if [[ ! -f "${PGP_FILE}" ]];
    then
      echo "PGPEncrypt: Failed to encrypt file ${PGP_FILE} since it does not exist."
      rm -rf "${PGP_PATH_HOME_DIR}"
      return -3
    fi
    local encrypt_status
    encrypt_status=$(gpg --homedir "${PGP_PATH_HOME_DIR}" -e -o "${PGP_FILE_OUT}" "${PGP_FILE}")
    local encrypt_ret_code=$?
    if [[ $encrypt_ret_code -ne 0 ]];
    then 
      echo "PGPEncrypt: Failed to encrypt file ${PGP_FILE} due to error ${encrypt_ret_code}"
      echo "${encrypt_status}"
      rm -rf "${PGP_PATH_HOME_DIR}"
      return -4
    fi
  else
    gpg --homedir "${PGP_PATH_HOME_DIR}" -d
    local encrypt_ret_code=$?
    if [[ $encrypt_ret_code -ne 0 ]];
    then
      echo "PGPEncrypt: Failed to encrypt input due to error ${encrypt_ret_code}"
      rm -rf "${PGP_PATH_HOME_DIR}"
      return -5 
    fi
  fi
  rm -rf "${PGP_PATH_HOME_DIR}"
}
