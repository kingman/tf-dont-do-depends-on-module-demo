data "local_file" "root_config_file" {
  filename = var.root_config_file_path
}

locals {
  config_obj = yamldecode(data.local_file.root_config_file.content)
}

output "module_name" {
  value = local.config_obj.demo.module-a.name
}
