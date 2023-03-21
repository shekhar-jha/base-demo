#!/bin/bash

SCRIPT_DEFAULT_HOME=$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd)
DEFAULT_HOME=$(pwd)

usage() {
  echo "Usage: $0 -e <environment name> -t <type: GCP|AWS> [-n <image name>] [-l] [-b] [-c]" 1>&2
  exit 1
}

while getopts ":e:t:n:bcl" options; do
  case "${options}" in
  e)
    ENV_NAME="${OPTARG}"
    if [[ "${ENV_NAME}" == "" ]]; then
      usage
    fi
    ;;
  t)
    INFRA_CLOUD_TYPE="${OPTARG}"
    if [[ "${INFRA_CLOUD_TYPE}" == "" ]]; then
      usage
    fi
    ;;
  n)
    IMG_NAME="${OPTARG}"
    if [[ "${IMG_NAME}" == "" ]]; then
      usage
    fi
    ;;
  b)
    SKIP_BUILD=true
    ;;
  c)
    SKIP_CONTAINER=true
    ;;
  l)
    LOCAL_MODE=true
    ;;

  :)
    echo "Error: -${OPTARG} requires an argument."
    usage
    ;;
  *)
    usage
    ;;
  esac
done

if [[ "${ENV_NAME}" == "" ]]; then
  usage
fi
if [[ "${INFRA_CLOUD_TYPE}" == "" ]] || { [[ "${INFRA_CLOUD_TYPE}" != "GCP" ]] && [[ "${INFRA_CLOUD_TYPE}" != "AWS" ]]; }; then
  usage
fi

function ImageCleanup {
  if [ "${1}" == "" ]; then
    echo "ImageCleanup <Image Name>"
    return 1
  fi
  local IMG_NM="${1}"
  local CONTAINERS
  CONTAINERS=$(docker ps -a -q --filter "ancestor=${IMG_NM}")
  if [[ "${CONTAINERS}" != "" ]]; then
    echo "Stopping all containers matching ${IMG_NM}"
    local stop_err
    docker stop $(docker ps -a -q --filter "ancestor=${IMG_NM}")
    stop_err=$?
    if [[ $stop_err -ne 0 ]]; then
      echo "Failed to stop containers associated with ${IMG_NM} due to error code ${stop_err}"
      return 2
    fi
    echo "Deleting all containers matching ${IMG_NM}"
    local rm_err
    docker rm $(docker ps -a -q --filter "ancestor=${IMG_NM}")
    rm_err=$?
    if [[ $rm_err -ne 0 ]]; then
      echo "Failed to delete containers associated with ${IMG_NM} due to error code ${rm_err}"
      return 3
    fi
  fi
  local IMAGES
  IMAGES=$(docker image ls -a -q "${IMG_NM}")
  if [[ "${IMAGES}" != "" ]]; then
    echo "Removing image ${IMG_NM}"
    local rmi_err
    docker rmi "${IMG_NM}"
    rmi_err=$?
    if [[ $rmi_err -ne 0 ]]; then
      echo "Failed to remove container ${IMG_NM} due to error code ${rmi_err}"
      return 4
    fi
  fi
  return 0
}

SKIP_BUILD=${SKIP_BUILD:-false}
SKIP_CONTAINER=${SKIP_CONTAINER:-false}
LOCAL_MODE=${LOCAL_MODE:-false}
INFRA_CLOUD_TYPE=$(echo "${INFRA_CLOUD_TYPE}" | tr '[:upper:]' '[:lower:]')
CODE_DIR="${SCRIPT_DEFAULT_HOME}/../cmd"
CODE_CHECK_FILE="${CODE_DIR}/go.mod"
APP_NAME="app"
DOCKER_DIR="${SCRIPT_DEFAULT_HOME}/docker"
DOCKER_FILE_NAME="Dockerfile-${INFRA_CLOUD_TYPE}"
IMG_NAME="${IMG_NAME:-base-demo}"
IMG_EXPOSE_PORT="${IMG_EXPOSE_PORT:-8080}"
DYNAMODB_PORT=8000
DYNAMODB_ENDPOINT="http://localhost:${DYNAMODB_PORT}"

if [[ "${SKIP_BUILD}" == "false" ]]; then
  if [[ ! -f "${CODE_CHECK_FILE}" ]]; then
    echo "No code to build. Check ${CODE_CHECK_FILE}"
    exit 2
  else
    echo "Building code...."
    cd "${CODE_DIR}" || exit 3
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o "${DOCKER_DIR}/${APP_NAME}" "."
    build_status=$?
    if [[ $build_status -ne 0 ]]; then
      echo "Build failed."
      exit 4
    fi
  fi
else
  echo "Skipping build..."
fi

if [[ "${SKIP_CONTAINER}" == "false" ]]; then
  if [[ -f "${DOCKER_DIR}/${DOCKER_FILE_NAME}" ]]; then
    ImageCleanup "${IMG_NAME}" || exit 5
    echo "Creating container..."
    docker build -f "${DOCKER_DIR}/${DOCKER_FILE_NAME}" --build-arg "APP_NAME=${APP_NAME}" --build-arg "LOG_ENABLED=1" --build-arg "EXPOSED_PORT=${IMG_EXPOSE_PORT}" -t "${IMG_NAME}" "${DOCKER_DIR}"
    build_err=$?
    if [[ $build_err -ne 0 ]]; then
      echo "Failed to build docker image ${IMG_NAME} due to error ${build_err}"
      exit 6
    fi
  else
    echo "Could not locate container file ${DOCKER_DIR}/${DOCKER_FILE_NAME}"
  fi
else
  echo "Skipping container creation.."
fi

if [[ "${LOCAL_MODE}" == "true" ]]; then
  echo "Starting a new container for ${IMG_NAME}"
  docker run -d -p 9000:8080 -h "${IMG_NAME}" --name "${IMG_NAME}" ${IMG_NAME}
  run_err=$?
  if [[ $run_err -ne 0 ]]; then
    echo "Failed to start container ${IMG_NAME} due to error ${run_err}"
    exit 7
  fi
  DYNAMODB_IMG_NAME="amazon/dynamodb-local"
  CONTAINERS=$(docker ps -a -q --filter "ancestor=${DYNAMODB_IMG_NAME}")
  if [[ "${CONTAINERS}" == "" ]]; then
    echo "No dynamodb instance running. Starting a new instance"
    # Needed sharedDb flag to avoid ResourceNotFound exception
    docker run -p "${DYNAMODB_PORT}:8000" --name dynamodb -d amazon/dynamodb-local -jar DynamoDBLocal.jar -inMemory -sharedDb
    dynamodb_result=$?
    if [[ $dynamodb_result -ne 0 ]]; then
      echo "Failed to start a new instance of dynamodb"
    fi
  fi
  TABLE_CHECK="Messages"
  table_output=$(aws dynamodb list-tables --endpoint-url "${DYNAMODB_ENDPOINT}" --region "us-east-1" --output text --query "TableNames[?@=='${TABLE_CHECK}']")
  table_result=$?
  if [[ table_result -ne 0 ]]; then
    echo "Failed to check whether table ${TABLE_CHECK} exists due to error ${table_result}"
    exit 8
  else
    if [[ "${table_output}" != "${TABLE_CHECK}" ]]; then
      echo "Creating tables on dynamodb"
      export AWS_ACCESS_KEY_ID=dummy
      export AWS_SECRET_ACCESS_KEY=dummy
      export AWS_SESSION_TOKEN=dummy
      aws dynamodb create-table --cli-input-json file://${DOCKER_DIR}/dynamodb-ddl.json --region "us-east-1" --endpoint-url "${DYNAMODB_ENDPOINT}"
    else
      echo "Table ${TABLE_CHECK} already exists. No update needed on dynamodb"
    fi
  fi
fi
