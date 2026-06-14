# =============================================================================
# cloudsql: Cloud SQL (PostgreSQL) / VPC Peering / Secret Manager
# -----------------------------------------------------------------------------
# 処理結果を保存するリレーショナルDB。
# このモジュールは「単体で完結」する。VPC も自分で作る（vpc-network には依存しない）。
#   → vpc-network と名前が衝突しないよう、VPC 名は ${env}-${vpc_name}（demo-sql）にする。
#
# ファイル構成:
#   main.tf      - provider と API 有効化
#   network.tf   - VPC / Private Service Access（vpc-network 相当の部分）
#   cloudsql.tf  - Cloud SQL インスタンス / データベース / ユーザー
#   secret.tf    - Secret Manager（パスワード保存）
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
    "compute.googleapis.com",           # VPC（このモジュールで自作するため）
    "sqladmin.googleapis.com",          # Cloud SQL Admin API
    "servicenetworking.googleapis.com", # VPC Peering（Private Service Access）
    "secretmanager.googleapis.com",     # Secret Manager API
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}
