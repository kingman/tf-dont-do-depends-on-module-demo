locals {
  source_root_dir    = "../.."
}

resource "null_resource" "poetry_install" {
  provisioner "local-exec" {
    when        = create
    command     = "poetry install"
    working_dir = local.source_root_dir
  }

  depends_on = [ some_upstream_resource ] /* explicit dependency */
}

/* For null_resource terraform only keep state whether is has run or not 
unless you do destroy or -replace this code will only run once */

