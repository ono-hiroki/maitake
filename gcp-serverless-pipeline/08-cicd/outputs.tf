output "workload_identity_provider" {
  description = "GitHub Actions の auth ステップに渡す Provider のフルパス"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "cicd_service_account" {
  description = "GitHub Actions が impersonate する SA のメール"
  value       = google_service_account.cicd.email
}

output "runtime_service_account" {
  description = "デプロイ先ランタイム SA（actAs デモ用）"
  value       = google_service_account.runtime.email
}
