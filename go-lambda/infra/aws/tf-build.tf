locals {
  go_code_dir         = "../../cmd"
  code_directory_exists          = fileexists("${local.go_code_dir}/go.mod")
  go_lambda_file_path = "."
  go_lambda_zip_path  = "${local.go_lambda_file_path}/${local.go_lambda_handler_name}.zip"
  sourcecode_hash = sha1(join("", [for f in fileset(local.go_code_dir, "*.go") : filesha1("${local.go_code_dir}/${f}")]))
}

resource "null_resource" "build_go" {
  count    = local.code_directory_exists?1 : 0
  triggers = {
    dir_sha = local.sourcecode_hash
  }
  provisioner "local-exec" {
    command = <<-CompileAndZip
    TF_DIR="$PWD"
    cd "${local.go_code_dir}"
    GOOS=linux CGO_ENABLED=0 GOARCH=amd64 go build -o "$TF_DIR/${local.go_lambda_handler_name}" "."
    build_status=$?
    if [[ $build_status -ne 0 ]]; then
      exit 1
    fi
    cd "$TF_DIR"
    rm "${local.go_lambda_zip_path}"
    cp ./../docker/config.cfg ./
    zip ${local.go_lambda_zip_path} ./${local.go_lambda_handler_name} ./config.cfg
    CompileAndZip
  }
}
