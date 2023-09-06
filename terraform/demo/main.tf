locals {
  source_root_dir    = "../.."
  config_dir   = "config"
  config_template_file_path = "${local.source_root_dir}/${local.config_dir}/config.yaml.tftpl"
  config_file_path = "${local.source_root_dir}/${local.config_dir}/generated_config.yaml"
}

resource "local_file" "root_configuration" {
  filename = local.config_file_path
  content = templatefile("${local.config_template_file_path}", {
    project_id             = var.project_id
  })
}
