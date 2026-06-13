output "input_bucket" {
  description = "ファイル投入先の入力バケット名"
  value       = google_storage_bucket.input.name
}

output "workflow_name" {
  description = "Workflows 名"
  value       = google_workflows_workflow.main.name
}

output "eventarc_trigger_name" {
  description = "Eventarc トリガー名"
  value       = google_eventarc_trigger.main.name
}

output "job_name" {
  description = "Workflows から起動される Cloud Run Job 名"
  value       = google_cloud_run_v2_job.main.name
}

output "workflow_sa" {
  description = "Workflows 実行用 SA"
  value       = google_service_account.workflow.email
}

output "eventarc_sa" {
  description = "Eventarc トリガー用 SA"
  value       = google_service_account.eventarc.email
}
