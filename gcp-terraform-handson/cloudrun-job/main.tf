# =============================================================================
# cloudrun-job: Cloud Run Job / Artifact Registry / Service Account
# -----------------------------------------------------------------------------
# バッチ処理の本体。
# このモジュールは単体で完結する。
#
# 構成（ファイル分割）:
#   main.tf               - provider と API 有効化
#   service-account.tf    - 実行用 Service Account と IAM ロール（最小権限）
#   artifact-registry.tf  - コンテナイメージの置き場（Docker リポジトリ）
#   cloud-run-job.tf      - Cloud Run Job（バッチ実行のコンテナ）
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

# 必要な API
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",              # Cloud Run（Job/Service）
    "artifactregistry.googleapis.com", # Artifact Registry（イメージ置き場）
    "iam.googleapis.com",              # Service Account
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}
