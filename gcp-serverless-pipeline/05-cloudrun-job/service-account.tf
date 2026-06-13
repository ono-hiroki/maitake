# =============================================================================
# service-account.tf - Cloud Run Job 実行用の Service Account と IAM ロール
# -----------------------------------------------------------------------------
# Service Account（SA）= アプリ/ジョブが「誰として」GCP API を呼ぶかの ID。
# 人間のアカウントではなく、ワークロード用の機械アカウント。
# 必要な権限だけをロールで付与する（最小権限の原則）。
# =============================================================================

resource "google_service_account" "job" {
  account_id   = "${var.env}-${var.name}-job"
  display_name = "Cloud Run Job 実行用 SA (${var.env}-${var.name})"
  description  = "GCPサーバーレスパイプライン学習 05-cloudrun-job のジョブ実行用 SA"
}

# -----------------------------------------------------------------------------
# プロジェクトレベルの IAM ロール付与
# demo 実運用構成はジョブが Cloud SQL / BigQuery / Firestore / Vertex AI / ログ等に
# アクセスするため以下を付与している:
#   roles/cloudsql.client, roles/bigquery.dataEditor, roles/bigquery.jobUser,
#   roles/datastore.user, roles/logging.logWriter, roles/monitoring.metricWriter,
#   roles/aiplatform.user
# この学習モジュールは単体完結なので、まず「どんなジョブでも要る」ログ/メトリクスと、
# 02-bigquery を触った流れで BigQuery への書き込み権限を代表例として付与する。
# （IAM の project binding は対象リソースが存在しなくても付与できる）
# -----------------------------------------------------------------------------
resource "google_project_iam_member" "job" {
  for_each = toset([
    "roles/logging.logWriter",       # ログ書き込み
    "roles/monitoring.metricWriter", # メトリクス書き込み
    "roles/bigquery.dataEditor",     # BigQuery テーブルへの読み書き
    "roles/bigquery.jobUser",        # BigQuery クエリ/ジョブ実行
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.job.email}"
}
