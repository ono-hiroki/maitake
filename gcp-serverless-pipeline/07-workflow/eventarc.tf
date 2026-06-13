# =============================================================================
# eventarc.tf - Eventarc トリガー + SA + サービスエージェント権限
# -----------------------------------------------------------------------------
# Eventarc = 「GCS にオブジェクトが作られた」イベントを受けて Workflows を起動する。
# 必要な権限が多いのが特徴（イベント駆動は登場人物が多い）:
#   - Eventarc トリガー実行用 SA: eventReceiver + workflows.invoker
#   - Eventarc サービスエージェント: eventarc.serviceAgent
#   - GCS サービスエージェント: pubsub.publisher（storage.tf で付与）
# =============================================================================

# Eventarc トリガーが「誰として」動くか
resource "google_service_account" "eventarc" {
  account_id   = "${var.env}-${var.name}-ea"
  display_name = "Eventarc トリガー用 SA (07-workflow)"
}

resource "google_project_iam_member" "eventarc" {
  for_each = toset([
    "roles/eventarc.eventReceiver", # イベント受信
    "roles/workflows.invoker",      # Workflows 起動
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.eventarc.email}"
}

# Eventarc のサービスエージェント（API 有効化で作られる専用 SA）に serviceAgent ロール
resource "google_project_service_identity" "eventarc" {
  provider = google-beta
  project  = var.project_id
  service  = "eventarc.googleapis.com"

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "eventarc_service_agent" {
  project = var.project_id
  role    = "roles/eventarc.serviceAgent"
  member  = "serviceAccount:${google_project_service_identity.eventarc.email}"
}

# サービスエージェントへの権限付与は反映に少し時間がかかる。
# 付与直後にトリガーを作ると 400(Permission denied ... Service Agent) になるため、
# 伝播のための待機を明示的に挟む（IaC で「待つ」を表現する定番パターン）。
resource "time_sleep" "wait_for_eventarc_agent" {
  depends_on      = [google_project_iam_member.eventarc_service_agent]
  create_duration = "120s"
}

# -----------------------------------------------------------------------------
# Eventarc トリガー本体
# GCS の finalized（オブジェクト作成完了）イベントを、指定バケットで監視し、
# Workflows を起動先(destination)にする。
# -----------------------------------------------------------------------------
resource "google_eventarc_trigger" "main" {
  provider = google-beta

  name     = "${var.env}-${var.name}"
  location = var.region

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }
  matching_criteria {
    attribute = "bucket"
    value     = google_storage_bucket.input.name
  }

  destination {
    workflow = google_workflows_workflow.main.id
  }

  service_account = google_service_account.eventarc.email

  # トリガー作成は関連 IAM が揃い、サービスエージェント権限が伝播してから
  depends_on = [
    google_project_iam_member.eventarc,
    google_project_iam_member.gcs_pubsub_publisher,
    time_sleep.wait_for_eventarc_agent,
  ]

  lifecycle {
    ignore_changes = [transport]
  }
}
