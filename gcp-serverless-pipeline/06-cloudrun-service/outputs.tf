output "service_account_email" {
  description = "Cloud Run Service 実行用 SA のメールアドレス"
  value       = google_service_account.service.email
}

output "service_name" {
  description = "Cloud Run Service 名"
  value       = google_cloud_run_v2_service.main.name
}

output "service_uri" {
  description = "Cloud Run Service の URL（IAP 経由でアクセス）"
  value       = google_cloud_run_v2_service.main.uri
}

output "iap_service_agent" {
  description = "run.invoker を付与した IAP サービスエージェント"
  value       = google_project_service_identity.iap.email
}

output "artifact_registry_repo" {
  description = "Artifact Registry リポジトリ名"
  value       = google_artifact_registry_repository.main.repository_id
}
