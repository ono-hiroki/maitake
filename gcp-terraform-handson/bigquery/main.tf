# =============================================================================
# bigquery: BigQuery Dataset / Table
# -----------------------------------------------------------------------------
# 処理データの保存先を学ぶ。
#
# BigQuery の階層:
#   Project ─ Dataset（テーブルの入れ物。location を持つ）─ Table（スキーマを持つ）
# サーバレスなデータウェアハウス。インスタンス管理不要で、保存量とスキャン量で課金。
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

# BigQuery を使うための API
resource "google_project_service" "bigquery" {
  project            = var.project_id
  service            = "bigquery.googleapis.com"
  disable_on_destroy = false
}

# -----------------------------------------------------------------------------
# Dataset（テーブルの入れ物）
# - dataset_id は英数字とアンダースコアのみ。ハイフン不可なので replace で _ に変換。
#   （実運用構成も replace("${var.env}_${var.project_name}", "-", "_") としている）
# - location は作成後に変更不可。リージョン（asia-northeast1）かマルチリージョン（US/EU）。
# - delete_contents_on_destroy: テーブルが残っていても destroy できるかどうか。
#   実運用構成は false（誤削除防止）。学習用は true にして destroy を楽にする。
# -----------------------------------------------------------------------------
resource "google_bigquery_dataset" "main" {
  dataset_id                 = replace("${var.env}_${var.dataset_name}", "-", "_")
  friendly_name              = "${var.env}-${var.dataset_name}"
  description                = "GCP Terraform ハンズオン 学習用データセット"
  location                   = var.region
  delete_contents_on_destroy = true

  depends_on = [google_project_service.bigquery]
}

# -----------------------------------------------------------------------------
# Table（スキーマ付き）
# demo が「処理対象データ」を保存するイメージのサンプルテーブル。
# schema は JSON 文字列で定義する。mode は NULLABLE / REQUIRED / REPEATED。
# -----------------------------------------------------------------------------
resource "google_bigquery_table" "documents" {
  dataset_id          = google_bigquery_dataset.main.dataset_id
  table_id            = "documents"
  deletion_protection = false # 学習用。true だと terraform でテーブル削除不可

  schema = jsonencode([
    {
      name        = "document_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "ドキュメントの一意ID"
    },
    {
      name        = "title"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "タイトル"
    },
    {
      name        = "content"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "本文"
    },
    {
      name        = "created_at"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "作成日時"
    },
  ])
}
