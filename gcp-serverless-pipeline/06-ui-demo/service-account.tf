# =============================================================================
# service-account.tf - Cloud Run Service 実行用の Service Account と IAM
# -----------------------------------------------------------------------------
# このアプリ（コンテナ）が「誰として」GCP API を呼ぶかの ID。
# demo の demo-ui は BigQuery/Firestore/Cloud SQL の参照や GCS 操作を行うため
# 多くのロールを持つが、ここは単体完結なので代表例（ログ/メトリクス + BQ参照）に絞る。
# =============================================================================

resource "google_service_account" "service" {
  account_id   = "${var.env}-${var.name}-run"
  display_name = "Cloud Run Service 実行用 SA (${var.env}-${var.name})"
  description  = "GCPサーバーレスパイプライン学習 06-ui-demo のサービス実行用 SA"
}

resource "google_project_iam_member" "service" {
  for_each = toset([
    "roles/logging.logWriter",       # ログ書き込み
    "roles/monitoring.metricWriter", # メトリクス書き込み
    "roles/bigquery.dataViewer",     # BigQuery 参照（可視化のため読み取り）
    "roles/bigquery.jobUser",        # BigQuery クエリ実行
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.service.email}"
}
