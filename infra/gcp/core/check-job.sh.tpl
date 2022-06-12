IMAGE_EXISTS=$(gcloud beta artifacts docker images list ${1} --filter="package:git_runner" "--format=value(package)" --limit=1 2>/dev/null)
JOB_CREATED=$(gcloud beta run jobs list "--filter=metadata.name:${2}" "--format=value(metadata.name)" 2>/dev/null)

echo "{ \"image\" : \"${IMAGE_EXISTS}\",  \"job\" : \"${JOB_CREATED}\" }"

