# =============================================================================
# 03-firestore: Firestore Database
# -----------------------------------------------------------------------------
# demo の firestore モジュール相当。demo ではプロンプト等の保存に使う。
#
# Firestore = サーバレスな NoSQL ドキュメントDB。
#   階層: Database ─ Collection ─ Document（JSON 風の階層データ）
# BigQuery（分析向けの表形式）との対比で「アプリの可変データ向け」と捉えると分かりやすい。
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

# Firestore を使うための API
resource "google_project_service" "firestore" {
  project            = var.project_id
  service            = "firestore.googleapis.com"
  disable_on_destroy = false
}

# -----------------------------------------------------------------------------
# Firestore Database
# - name: プロジェクト内で一意。最初に作るものを "(default)" にする運用もあるが、
#   ここでは名前付きDB（named database）を作る。
# - location_id: 作成後に変更不可。リージョン（asia-northeast1）かマルチリージョン。
# - type: FIRESTORE_NATIVE（推奨）か DATASTORE_MODE（旧 Datastore 互換）。
# - point_in_time_recovery: 過去の任意時点に復元できる機能。
# - delete_protection_state: 実運用構成は ENABLED（誤削除防止）。学習用は DISABLED で destroy 可。
# -----------------------------------------------------------------------------
resource "google_firestore_database" "main" {
  project     = var.project_id
  name        = "${var.env}-${var.db_name}"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"

  concurrency_mode                  = "OPTIMISTIC"
  app_engine_integration_mode       = "DISABLED"
  point_in_time_recovery_enablement = "POINT_IN_TIME_RECOVERY_ENABLED"
  delete_protection_state           = "DELETE_PROTECTION_DISABLED"

  depends_on = [google_project_service.firestore]
}
