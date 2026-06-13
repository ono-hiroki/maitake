# =============================================================================
# pubsub-minimal: Pub/Sub 単体の最小構成
# -----------------------------------------------------------------------------
# Pub/Sub = メッセージングの土台（publisher → topic → subscription → subscriber）。
# Eventarc が裏で使っている仕組みを、単体で publish/pull して体感する。
# =============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_project_service" "pubsub" {
  project            = var.project_id
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}

# トピック（メッセージの送り先）
resource "google_pubsub_topic" "main" {
  name       = var.name
  depends_on = [google_project_service.pubsub]
}

# サブスクリプション（メッセージの受け口）。pull 型で手元から取り出す。
resource "google_pubsub_subscription" "main" {
  name  = "${var.name}-sub"
  topic = google_pubsub_topic.main.id

  # 受信後に確認応答(ack)しなかった場合の再配信までの猶予
  ack_deadline_seconds = 10
  # メッセージ保持期間
  message_retention_duration = "600s"
}
