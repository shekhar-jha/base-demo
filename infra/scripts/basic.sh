
function IsAvailable {
  if [ "${1}" == "" -o "${2}" == "" -o "${3}" == "" ];
  then
    echo "IsAvailable <Type: Command|Function> <Name> <Description> [<Exit: [e]xit*|[r]eturn>]"
    exit
  fi
  local NOT_EXIST=1
  case $1 in
 
    Command|command|c)
      $(command -v ${2} &>/dev/null)
      NOT_EXIST=$?
      ;;

    Function|function|f)
      $(declare -F "$2" > /dev/null;)
      NOT_EXIST=$?
      ;;

    *)
      echo "IsAvailable: Only type Command/command/c & Function/function/f are supported"
      exit
  esac
  if [ $NOT_EXIST -eq 1 ];
  then
    echo "${3} is not available"
    case "$4" in
    
      "exit"|e|"")
        exit
        ;;

      "return"|r)
        return -1
        ;;
      
      *)
        echo "IsAvailable: Only Exit value exit|e and return|r is supported. Passed"
        exit
        ;;
      
    esac
  # else
    #echo "${3} is available"
  fi
  return 0
}

function ReturnOrExit {
  if [[ "${1}" == "" ]] || [[ "${2}" == "" ]] || [[ "${3}" == "" ]];
  then
    echo 'ReturnOrExit <Type: Return|Exit> <Exit Code> <Return Code>'
    exit 2
  fi
  local REQUESTED_RETURN_TYPE="${1:-Exit}"
  local REQUESTED_EXIT_CODE="${2:-0}"
  local EXIT_CODE=$((REQUESTED_EXIT_CODE + 0))
  local REQUESTED_RETURN_CODE="${3:-0}"
  local RETURN_CODE=$((REQUESTED_RETURN_CODE + 0))
  case "${REQUESTED_RETURN_TYPE}" in
    r|R|Return|return)
      return $RETURN_CODE
      ;;

    e|E|Exit|exit|*)
      exit $EXIT_CODE
      ;;
  esac
  exit $EXIT_CODE
}