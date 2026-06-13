output "workflow_name" {
  description = "作成した Workflow 名"
  value       = google_workflows_workflow.main.name
}
