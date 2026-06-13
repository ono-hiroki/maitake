# =============================================================================
# storage.tf - 入力 GCS バケット（イベントの発生源）
# -----------------------------------------------------------------------------
# ここにファイルを置く（finalized）と Eventarc が検知して Workflows を起動する。
# =============================================================================

resource "google_storage_bucket" "input" {
  name     = "${var.project_id}-${var.env}-${var.name}-input" # バケット名はグローバル一意
  location = var.region

  uniform_bucket_level_access = true
  force_destroy               = true # 学習用: 中身があっても destroy 可

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# GCS のサービスエージェントに Pub/Sub Publisher を付与
# Eventarc の GCS トリガーは「GCS → Pub/Sub 通知」を裏で使う。そのため GCS の
# サービスアカウントが Pub/Sub に publish できる必要がある。
# google_storage_project_service_account で GCS の SA メールを取得する。
# -----------------------------------------------------------------------------
data "google_storage_project_service_account" "gcs" {
  project = var.project_id
}

resource "google_project_iam_member" "gcs_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
}
