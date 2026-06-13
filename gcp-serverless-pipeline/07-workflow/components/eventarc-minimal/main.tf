# =============================================================================
# eventarc-minimal: Eventarc 単体の最小構成
# -----------------------------------------------------------------------------
# 最小の「イベント → 自動起動」: Pub/Sub トピックにメッセージが publish されたら
# Eventarc が Workflow を起動する。GCS も Cloud Run Job も使わない最小形。
#
# 07 本体との違い: イベント源を GCS ではなく Pub/Sub にすることで、
# 「GCS サービスエージェントへの pubsub.publisher 付与」が不要になり、より単純。
# それでも Eventarc に必要な「SA + サービスエージェント + 伝播待ち」は登場する
# （＝イベント駆動の最小でも避けられない要素、というのが学び）。
# =============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    google      = { source = "hashicorp/google", version = "~> 6.0" }
    google-beta = { source = "hashicorp/google-beta", version = "~> 6.0" }
    time        = { source = "hashicorp/time", version = "~> 0.9" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
provider "google-beta" {
  project = var.project_id
  region  = var.region
}

resource "google_project_service" "apis" {
  for_each = toset([
    "workflows.googleapis.com",
    "eventarc.googleapis.com",
    "pubsub.googleapis.com",
    "logging.googleapis.com",
    "iam.googleapis.com",
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# --- イベント源: Pub/Sub トピック ---------------------------------------------
resource "google_pubsub_topic" "source" {
  name       = "${var.name}-topic"
  depends_on = [google_project_service.apis]
}

# --- 起動先: 最小の Workflow（イベントを受けてログするだけ） -------------------
resource "google_service_account" "wf" {
  account_id   = "${var.name}-wf"
  display_name = "eventarc-minimal Workflow SA"
}
resource "google_project_iam_member" "wf_log" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.wf.email}"
}
resource "google_workflows_workflow" "main" {
  name                = "${var.name}-wf"
  region              = var.region
  service_account     = google_service_account.wf.email
  call_log_level      = "LOG_ALL_CALLS"
  deletion_protection = false
  source_contents     = file("${path.module}/workflow.yaml")
  depends_on          = [google_project_iam_member.wf_log]
}

# --- Eventarc: トリガー用 SA とその権限 ---------------------------------------
resource "google_service_account" "ea" {
  account_id   = "${var.name}-ea"
  display_name = "eventarc-minimal トリガー SA"
}
resource "google_project_iam_member" "ea" {
  for_each = toset([
    "roles/eventarc.eventReceiver",
    "roles/workflows.invoker",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.ea.email}"
}

# Eventarc サービスエージェント（基盤用 SA）に serviceAgent
resource "google_project_service_identity" "eventarc" {
  provider   = google-beta
  project    = var.project_id
  service    = "eventarc.googleapis.com"
  depends_on = [google_project_service.apis]
}
resource "google_project_iam_member" "ea_agent" {
  project = var.project_id
  role    = "roles/eventarc.serviceAgent"
  member  = "serviceAccount:${google_project_service_identity.eventarc.email}"
}

# 権限伝播待ち（07 本体と同じハマりどころ対策）
resource "time_sleep" "wait" {
  depends_on      = [google_project_iam_member.ea_agent]
  create_duration = "120s"
}

# --- Eventarc トリガー本体: Pub/Sub publish → Workflow ------------------------
resource "google_eventarc_trigger" "main" {
  provider = google-beta
  name     = "${var.name}-trigger"
  location = var.region

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.pubsub.topic.v1.messagePublished"
  }

  destination {
    workflow = google_workflows_workflow.main.id
  }

  # 既存トピックを transport に使う（指定しないと Eventarc が自動でトピックを作る）
  transport {
    pubsub {
      topic = google_pubsub_topic.source.id
    }
  }

  service_account = google_service_account.ea.email

  depends_on = [
    google_project_iam_member.ea,
    time_sleep.wait,
  ]
}
