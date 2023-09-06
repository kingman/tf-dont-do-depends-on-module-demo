## Clone the repo
```bash
git clone https://github.com/kingman/tf-dont-do-depends-on-module-demo.git
```
## Setup environment
```bash
cd tf-dont-do-depends-on-module-demo
SOURCE_ROOT=$(pwd)
```
### Create terraform.tfvars file
```bash
code "${SOURCE_ROOT}/terraform/demo/terraform.tfvars"
```
Add:
```tf
project_id = "demo-project-123"
```
## Module A

### Add module

```bash
code "${SOURCE_ROOT}/terraform/demo/main.tf"
```

Add:

```tf
module "module_a" {
  source = "./modules/module-a"
  root_config_file_path = local_file.root_configuration.filename
}

output "module_a_name" {
  value = module.module_a.module_name
}
```

### Test

Install:
```bash
cd "${SOURCE_ROOT}/terraform/demo"
terraform init
```

Validate:
```bash
terraform validate
```

Plan:
```bash
terraform plan
```
We get the `no such file or directory` error.

### Fix
Add `depends_on`:
```tf
depends_on = [ local_file.root_configuration ]
```

Plan:
```bash
terraform plan
```

Apply:
```bash
terraform apply
```
Verify outputs:
```
module_a_name = "demo-project-123-demo-suffix"
```

Error gone! All good! Right?

Clean:
```bash
terraform destroy
```

## Add more resource to Module A
### Add resource
```bash
code "${SOURCE_ROOT}/terraform/demo/modules/module-a/main.tf"
```
Add:
```tf
module "gcloud_project_get" {
  source          = "terraform-google-modules/gcloud/google"
  version         = "3.1.2"
  platform        = "linux"
  create_cmd_body = "config get project"
}
```
### Test
Install:
```bash
cd "${SOURCE_ROOT}/terraform/demo"
terraform init
```

Validate:
```bash
terraform validate
```

Plan:
```bash
terraform plan
```
Fails with:
```
│ Error: Invalid count argument
│ 
│   on .terraform/modules/module_a.gcloud_project_get/main.tf line 57, in resource "random_id" "cache":
│   57:   count = (!local.skip_download) ? 1 : 0
│ 
│ The "count" value depends on resource attributes that cannot be determined until apply, so Terraform cannot predict how many instances will be created. To work around this, use the -target argument to first apply only
│ the resources that the count depends on.
```
WUT????

Some googling lead to this [issue](https://github.com/terraform-google-modules/terraform-google-gcloud/issues/82) with some positive reaction on use `module_depends_on` instead, lets try it...

### Fix
Replace `depends_on` with `module_depends_on`
```bash
code "${SOURCE_ROOT}/terraform/demo/main.tf"
```
### Test
Validate:
```bash
terraform validate
```

Validation fails with:
```
An argument named "module_depends_on" is not expected here.
```
What is happening? The gcloud module should work, because it used else where. Frustration!!!

## Get rid of depends_on
In this case it's obvious that the `depends_on` on module is the culprit. Imagine that you have a module that consists of many resources, the debugging and the root cause analysis would not be this simple.

## Issues with depends_on on module
When `depends_on` meta-argument is added a module make all the resources and data sources of the module dependent of the objects specified in the `depends_on` meta-argument. This has effect on how terraform calculates the plan. More specifically even resources in a module is not dependent on the specified dependency objects, they still needs to wait for all actions to complete on the upstream objects before actions can be performed on themselfes. In our case the **gcloud module** inside of **module-a** becomes dependent to **local_file** resource, this prevents terraform from calculating the plan for the **gcloud module**.

`depends_on` meta-argument also effects on how terraform apply changes/updates. In our case any changes done on **local_file** resource would force in all the resources in **module-a** are replace, even the changes don't effects the actual properties of the resources.

### Express the explicit dependency
The issue we face is that terraform plan is greedy it try to evaluate all the values that are available at the planning stage. The value of `local_file.root_configuration.filename` is known at the planning stage which lead to terraform try to read the file which does not exist. We need add dependency to an attribute that is only known after the file is create and delays terraform evaluation of the variable value.
Lets look at the [local_file resource doc](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file#read-only).

The `id` attribute which contains the hexadecimal encoding of the SHA1 checksum of the file content, should only have value when the file is created. Lets use it to delay the terraform evaluation!

Change the module variable assigment from:
```tf
root_config_file_path = local_file.root_configuration.filename
```
to:
```tf
root_config_file_path = local_file.root_configuration.id != "" ? local_file.root_configuration.filename : ""
```

### Test
Validate:
```bash
terraform validate
```

Plan:
```bash
terraform plan
```

Apply:
```bash
terraform apply
```
```
module.module_a.module.gcloud_project_get.null_resource.run_destroy_command[0]: Creating...
module.module_a.module.gcloud_project_get.null_resource.run_command[0]: Creating...
module.module_a.module.gcloud_project_get.null_resource.run_destroy_command[0]: Creation complete after 0s [id=1729847943672922591]
local_file.root_configuration: Creating...
module.module_a.module.gcloud_project_get.null_resource.run_command[0]: Provisioning with 'local-exec'...
module.module_a.module.gcloud_project_get.null_resource.run_command[0] (local-exec): Executing: ["/bin/sh" "-c" "PATH=/google-cloud-sdk/bin:$PATH\ngcloud config get project\n"]
local_file.root_configuration: Creation complete after 0s [id=0bc0cd469f8d6b9d57ac2879b6653a78360e4d33]
module.module_a.data.local_file.root_config_file: Reading...
module.module_a.data.local_file.root_config_file: Read complete after 0s [id=0bc0cd469f8d6b9d57ac2879b6653a78360e4d33]
module.module_a.module.gcloud_project_get.null_resource.run_command[0] (local-exec): project-id-123
module.module_a.module.gcloud_project_get.null_resource.run_command[0]: Creation complete after 1s [id=9180274189510220086]

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

module_a_name = "demo-project-123-demo-suffix"
```
Now it works! Yeah!

## Conclusion
From the terraform execution output we can see that gcloud command execution started before the configuration file creation.

1. We have decoupled the dependency between configuration file creation from the gcloud command exection, we have now more precise dependency between resources in different modules.

1. To express dependency between resources, reference / use resource attributes, that reflects the correct state of the underlying resource, from the downstream dependent resources.  In our case the `local_file.root_configuration.id`, corresponding attribute can be found in most resources.

1. DO NOT USE `depends_on` on modules.

1. Need proper integration test environment catch terraform plan issues

## Clean up
```bash
terraform destroy
cd ../../..
rm -rf tf-dont-do-depends-on-module-demo/
```
