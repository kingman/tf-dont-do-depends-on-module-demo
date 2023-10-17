module "project_services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "14.1.0"

  disable_dependent_services  = false
  disable_services_on_destroy = false

  project_id = var.project_id

  activate_apis = [
    "secretmanager.googleapis.com",
    "pubsub.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "bigquery.googleapis.com",
    "bigquerystorage.googleapis.com",
    "analyticsadmin.googleapis.com",
    "eventarc.googleapis.com",
    "run.googleapis.com",
  ]
}

module "bigquery" {
  source       = "terraform-google-modules/bigquery/google"
  version      = "~> 5.4"
  dataset_id   = "demo_dataset"
  dataset_name = "demo_dataset"
  project_id   = var.project_id
  location     = "EU"

  depends_on = [module.project_services] /* module dependency introduced */
}

module "secret_manager" {
  source     = "GoogleCloudPlatform/secret-manager/google"
  version    = "~> 0.1"
  project_id = var.project_id
  secrets = [
    {
      name                  = "ga4-measurement-id"
      secret_data           = var.ga4_measurement_id
      automatic_replication = true
    },
  ]

  depends_on = [
    module.project_services /* module dependency introduced */
  ]
}

resource "google_cloudfunctions2_function" "demo_function" {
  name     = "demo-function"
  project  = var.project_id
  location = "europe-west1"

  build_config {
    runtime = "python311"
    source {
      storage_source {
        bucket = "cf-demo-bucket"
        object = "demo.zip"
      }
    }
    entry_point = "subscribe"
  }

  service_config {
    available_memory   = "256M"
    max_instance_count = 3
    timeout_seconds    = 60
    ingress_settings   = "ALLOW_INTERNAL_ONLY"
  }

  depends_on = [
    module.project_services /* module dependency introduced */
  ]
}

variable "project_id" {
  type = string

}

variable "ga4_measurement_id" {
  type = string
}
