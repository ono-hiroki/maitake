output "topic" {
  description = "イベント源の Pub/Sub トピック"
  value       = google_pubsub_topic.source.name
}

output "workflow_name" {
  description = "起動先 Workflow 名"
  value       = google_workflows_workflow.main.name
}

output "trigger_name" {
  description = "Eventarc トリガー名"
  value       = google_eventarc_trigger.main.name
}
