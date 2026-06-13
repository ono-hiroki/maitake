# =============================================================================
# 07-workflow: Eventarc / Workflows（イベント駆動オーケストレーション）
# -----------------------------------------------------------------------------
# データフロー全体の「つなぎ」。
# このモジュールは単体で完結する（入力バケットも呼び出し先 Job も自分で作る）。
#
# 実現する流れ（demo の心臓部）:
#   GCS にファイル投入
#     → Eventarc がオブジェクト作成イベント(finalized)を検知
#       → Workflows を起動
#         → Workflows が Cloud Run Job を実行（ファイル名を env で渡す）
#
# 登場サービスと役割:
#   Eventarc  = 「○○が起きたら△△を呼ぶ」イベントルーター（裏で Pub/Sub を使う）
#   Workflows = 複数 API 呼び出しを YAML で順に実行するサーバレスなオーケストレータ
#
# 構成（ファイル分割）:
#   main.tf          - provider / API / プロジェクト情報
#   storage.tf       - 入力 GCS バケット
#   cloud-run-job.tf - Workflows から起動される Cloud Run Job
#   workflow.tf      - Workflows 本体 + 実行用 SA
#   eventarc.tf      - Eventarc トリガー + SA + 各種サービスエージェント権限
#   workflow.yaml    - Workflows の処理定義
# =============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    # google_eventarc_trigger は google-beta が安定
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
    # サービスエージェント権限の伝播待ちに使う
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
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

data "google_project" "this" {
  project_id = var.project_id
}

# 必要な API
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",       # Cloud Run Job
    "workflows.googleapis.com", # Workflows
    "eventarc.googleapis.com",  # Eventarc
    "storage.googleapis.com",   # Cloud Storage
    "pubsub.googleapis.com",    # Eventarc が裏で使う Pub/Sub
    "iam.googleapis.com",       # Service Account
    "logging.googleapis.com",   # ログ
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}
