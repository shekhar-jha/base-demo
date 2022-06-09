CMD_PROFILE_SECTION=""
if [[ "${1}" != "" ]]; then
  CMD_PROFILE_SECTION=" --profile ${1}"
fi
PROVIDER_NAME=$(aws $CMD_PROFILE_SECTION iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')]" --output text)
if [[ "${PROVIDER_NAME}" != "" ]]; then
  ENV_TAG_VAL=$(aws $CMD_PROFILE_SECTION iam list-open-id-connect-provider-tags --open-id-connect-provider-arn "${PROVIDER_NAME}" --query "Tags[?contains(Key, 'Environment')].Value" --output text)
fi
echo "{ \"provider_name\" : \"${PROVIDER_NAME}\", \"env_tag_value\" : \"${ENV_TAG_VAL}\" }"
