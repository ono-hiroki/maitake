output "service_account_email" {
  description = "Cloud Run Job 実行用 SA のメールアドレス"
  value       = google_service_account.job.email
}

output "artifact_registry_repo" {
  description = "Artifact Registry リポジトリ名"
  value       = google_artifact_registry_repository.main.repository_id
}

output "artifact_registry_url" {
  description = "イメージ push 先のベース URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}"
}

output "job_name" {
  description = "Cloud Run Job 名"
  value       = google_cloud_run_v2_job.main.name
}
