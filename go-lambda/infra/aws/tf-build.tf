locals {
  go_code_dir           = "${path.module}/../../cmd"
  code_directory_exists = fileexists("${local.go_code_dir}/go.mod")
  sourcecode_hash       = sha1(join("", [
    for f in fileset(local.go_code_dir, "*.go") :filesha1("${local.go_code_dir}/${f}")
  ]))
  cfg_dir                      = "${path.module}/../cfg"
  docker_dir                   = "${path.module}/../docker"
  docker_build_file            = "Dockerfile-${var.DOCKER_IMAGE_TYPE}"
  package_build_dir            = "${path.module}/../package-build"
  package_build_dir_check_file = "${local.package_build_dir}/.checkExist"
  go_lambda_zip_path           = "${local.package_build_dir}/${local.go_lambda_handler_name}.zip"
  docker_image_expose_port     = 8080
  docker_image_name            = "base-demo"
  docker_image_repo_name       = "${var.ENV_NAME}-base-demo-${local.env_suffix}"
  docker_image_repo_location   = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
  docker_image_repo            = "${local.docker_image_repo_location}/${local.docker_image_repo_name}"
}

resource "null_resource" "package_build_dir" {
  count = fileexists(local.package_build_dir_check_file)?0 : 1
  provisioner "local-exec" {
    command = "mkdir -p ${local.package_build_dir};touch '${local.package_build_dir_check_file}'"
  }
}

resource "null_resource" "build_go" {
  count    = local.code_directory_exists?1 : 0
  triggers = {
    dir_sha = sha1(join(" ", [local.sourcecode_hash, timestamp()]))
  }
  provisioner "local-exec" {
    command = <<-Compile
    TF_DIR="$PWD"
    cd "${local.go_code_dir}"
    GOOS=linux CGO_ENABLED=0 GOARCH=amd64 go build -o "$TF_DIR/${local.package_build_dir}/${local.go_lambda_handler_name}" "."
    build_status=$?
    if [[ $build_status -ne 0 ]]; then
      exit 1
    fi
    cd "$TF_DIR"
    Compile
  }
  depends_on = [null_resource.package_build_dir]
}

resource "local_file" "package_build_config" {
  for_each   = fileset(local.cfg_dir, "*" )
  content    = templatefile("${local.cfg_dir}/${each.value}", { env = local.env_name_lower })
  filename   = "${local.package_build_dir}/${basename(each.value)}"
  depends_on = [null_resource.package_build_dir]
}

resource "local_file" "package_docker" {
  for_each = lower(var.PACKAGE_TYPE)=="image"?fileset(local.docker_dir, "*" ) : []
  content  = templatefile("${local.docker_dir}/${each.value}", {
    env          = local.env_name_lower,
    APP_NAME     = local.go_lambda_handler_name,
    EXPOSED_PORT = 8080
  })
  filename   = "${local.package_build_dir}/${basename(each.value)}"
  depends_on = [null_resource.package_build_dir]
}

resource "null_resource" "package_zip" {
  count    = fileexists(local.package_build_dir_check_file) && lower(var.PACKAGE_TYPE)=="zip"?1 : 0
  triggers = {
    dir_sha = sha1(join("", [
      for f in fileset(local.package_build_dir, "*") :filesha1("${local.package_build_dir}/${f}")
    ]))
  }
  provisioner "local-exec" {
    command = <<-Package
    rm "${local.go_lambda_zip_path}"
    zip ${local.go_lambda_zip_path} ./${local.go_lambda_handler_name} ./config.cfg
    Package
  }
  depends_on = [local_file.package_build_config, null_resource.build_go]
}

resource "null_resource" "build_image" {
  count    = fileexists(local.package_build_dir_check_file) && lower(var.PACKAGE_TYPE)=="image"?1 : 0
  triggers = {
    build_image_trigger = sha1(timestamp())
  }
  provisioner "local-exec" {
    command = <<-BuildImage
    docker build -f "${local.package_build_dir}/${local.docker_build_file}" --build-arg "LOG_ENABLED=1" --build-arg "EXPOSED_PORT=${local.docker_image_expose_port}" -t "${local.docker_image_name}" "${local.package_build_dir}" --tag "${aws_ecr_repository.image_repo.repository_url}"
    build_status=$?
    if [[ $build_status -ne 0 ]]; then
      exit 1
    fi
    aws ecr get-login-password --region "${data.aws_region.current.name}" | docker login --username AWS --password-stdin "${local.docker_image_repo_location}"
    docker push "${local.docker_image_repo}"
    push_status=$?
    if [[ $push_status -ne 0 ]]; then
      exit 1
    fi
    BuildImage
  }
  depends_on = [
    local_file.package_build_config, null_resource.build_go,
    local_file.package_docker, aws_ecr_repository.image_repo
  ]
}

resource "aws_ecr_repository" "image_repo" {
  name                 = local.docker_image_repo_name
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    # TODO: Migrate to KMS
    encryption_type = "AES256"
  }
  tags = {
    Name        = "${var.ENV_NAME} base-demo"
    Environment = var.ENV_NAME
  }
}