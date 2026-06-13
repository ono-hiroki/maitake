# =============================================================================
# cloud-run-job.tf - Workflows から起動される Cloud Run Job
# -----------------------------------------------------------------------------
# 05-application と同じく公式サンプルJobイメージを使う。Workflows が実行時に
# INPUT_BUCKET / INPUT_FILENAME を env で上書きして渡す（workflow.yaml 参照）。
# 実運用ではここが「処理の本体」になる。
# =============================================================================

resource "google_service_account" "job" {
  account_id   = "${var.env}-${var.name}-job"
  display_name = "Cloud Run Job 実行用 SA (07-workflow)"
}

resource "google_project_iam_member" "job" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.job.email}"
}

resource "google_cloud_run_v2_job" "main" {
  name     = "${var.env}-${var.name}"
  location = var.region

  deletion_protection = false # 学習用に destroy 可

  template {
    template {
      service_account = google_service_account.job.email
      max_retries     = 1

      containers {
        image = var.job_image

        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].image,
      template[0].template[0].containers[0].env,
      client,
      client_version,
    ]
  }

  depends_on = [google_project_service.apis]
}
