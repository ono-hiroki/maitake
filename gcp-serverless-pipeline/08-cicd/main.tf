# =============================================================================
# 08-cicd: Workload Identity Federation（鍵レス認証）
# -----------------------------------------------------------------------------
# GitHub Actions が「サービスアカウントキー(JSON)
# を一切持たずに」GCP へ認証してデプロイできるようにする仕組み。
#
# なぜ鍵レスか:
#   従来は SA キー(JSON) を GitHub Secrets に置いていた。これは
#   「漏れたら終わり・ローテーションが大変・棚卸し不能」という問題がある。
#   WIF は GitHub が発行する OIDC トークン（短命・リポジトリ情報入り）を
#   GCP が検証して、その場で短命の GCP クレデンシャルに交換する。鍵の保管が不要。
#
# 認証の流れ:
#   GitHub Actions 実行
#     → GitHub が OIDC トークンを発行（repo名・branch等のclaimを含む）
#       → GCP の Workload Identity Pool/Provider がトークンを検証
#         （issuer は token.actions.githubusercontent.com か？ owner は合っているか？）
#         → 検証OKなら CI/CD 用 SA として振る舞える（impersonation）
#           → Artifact Registry へ push / Cloud Run へデプロイ
#
# 構成（ファイル分割）:
#   main.tf            - provider / API
#   wif.tf             - Workload Identity Pool / OIDC Provider（鍵レスの核）
#   service-account.tf - CI/CD 用 SA / IAM ロール / WIF↔SA バインディング
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
    "iam.googleapis.com",            # Service Account / Workload Identity Pool
    "iamcredentials.googleapis.com", # SA impersonation（トークン交換）に必要
    "sts.googleapis.com",            # Security Token Service（OIDC→GCPトークン交換の入口）
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}
