
provider "google" {
  project     = "<PROJECT_ID>"
  region      = "<REGION>"
  zone       = "<ZONE>"
}

#APIs to enable
resource "google_project_service" "run_api" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam_api" {
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "resource_manager_api" {
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "scheduler_api" {
  service            = "cloudscheduler.googleapis.com"
  disable_on_destroy = false
}

# [START cloudrun_service_scheduled_service]
resource "google_cloud_run_v2_service" "default" {
  name     = "pipeline-cloud-run"
  location = "<REGION>"

  template {
    containers {
      image = "gcr.io/<PROJECT_ID>/<IMAGE_NAME>:<TAG>"
    }
  }

  # Use an explicit depends_on clause to wait until API is enabled
  depends_on = [
    google_project_service.run_api
  ]
}
# [END cloudrun_service_scheduled_service]

# [START cloudrun_service_scheduled_sa]
resource "google_service_account" "default" {
  account_id   = "scheduler-sa"
  description  = "Cloud Scheduler service account; used to trigger scheduled Cloud Run jobs."
  display_name = "scheduler-sa"

  # Use an explicit depends_on clause to wait until API is enabled
  depends_on = [
    google_project_service.iam_api
  ]
}

resource "google_cloud_run_service_iam_member" "default" {
  location = google_cloud_run_v2_service.default.location
  service  = google_cloud_run_v2_service.default.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.default.email}"
}
# [END cloudrun_service_scheduled_sa]

# [START cloudrun_service_scheduled_job]
resource "google_cloud_scheduler_job" "default" {
  name             = "scheduled-cloud-run-job"
  region           = "<REGION>"
  description      = "Invoke a Cloud Run container on a schedule."
  schedule         = "*/8 * * * *"
  time_zone        = "Germany/Berlin"
  attempt_deadline = "320s"

  retry_config {
    retry_count = 3
  }

  http_target {
    http_method = "POST"
    uri         = google_cloud_run_v2_service.default.uri

    oidc_token {
      service_account_email = google_service_account.default.email
    }
  }

  # Use an explicit depends_on clause to wait until API is enabled
  depends_on = [
    google_project_service.scheduler_api
  ]
}
# [END cloudrun_service_scheduled_job]