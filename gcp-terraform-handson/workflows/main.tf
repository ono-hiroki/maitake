# =============================================================================
# workflows-minimal: Workflows 単体の最小構成
# -----------------------------------------------------------------------------
# イベントも Cloud Run Job も無し。手動で実行する超小さい Workflow だけ。
# Workflows の「YAML で手順を書いて実行する」感覚をまず掴む。
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

resource "google_project_service" "apis" {
  for_each = toset([
    "workflows.googleapis.com",
    "logging.googleapis.com",
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# Workflow が実行時に名乗る SA（ログ出力のため logWriter だけ）
resource "google_service_account" "wf" {
  account_id   = var.name
  display_name = "workflows-minimal 実行用 SA"
}

resource "google_project_iam_member" "wf_log" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.wf.email}"
}

# Workflow 本体。source は workflow.yaml をそのまま読む（変数埋め込み不要なので file()）。
resource "google_workflows_workflow" "main" {
  name                = var.name
  region              = var.region
  description         = "最小構成の Workflow（手動実行）"
  service_account     = google_service_account.wf.email
  call_log_level      = "LOG_ALL_CALLS"
  deletion_protection = false
  source_contents     = file("${path.module}/workflow.yaml")

  depends_on = [google_project_iam_member.wf_log]
}
