output "dataset_id" {
  description = "BigQuery Dataset ID"
  value       = google_bigquery_dataset.main.dataset_id
}

output "dataset_full_id" {
  description = "完全修飾の Dataset ID（project:dataset 形式）"
  value       = "${var.project_id}:${google_bigquery_dataset.main.dataset_id}"
}

output "table_id" {
  description = "作成したテーブルの ID"
  value       = google_bigquery_table.documents.table_id
}
