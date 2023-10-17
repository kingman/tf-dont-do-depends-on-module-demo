locals {
  source_root_dir    = "../.."
  poetry_cmd = "poetry"
  project_toml_file_path    = "${local.source_root_dir}/pyproject.toml"
  project_toml_content_hash = filesha512(local.project_toml_file_path)
}


resource "null_resource" "poetry_install" {
  triggers = {
    create_command       = "${local.poetry_cmd} install"
    source_contents_hash = local.project_toml_content_hash
    some_upstream_dependency = some_upstream_dependency.output_attribute
  }

  provisioner "local-exec" {
    when        = create
    command     = self.triggers.create_command
    working_dir = local.source_root_dir
  }
}