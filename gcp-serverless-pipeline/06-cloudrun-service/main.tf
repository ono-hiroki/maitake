# =============================================================================
# 06-cloudrun-service: Cloud Run Service / IAP 認証 / Service Account
# -----------------------------------------------------------------------------
# Cloud Run Service（常駐 HTTP アプリ）と IAP 認証の最小構成。
# このモジュールは単体で完結する。
#
# 05-cloudrun-job（Cloud Run Job）との対比:
#   Job     = 実行して完了するバッチ（リクエストを受けない）
#   Service = 常駐して HTTP リクエストを受け続ける（Web アプリ/API）
#
# IAP（Identity-Aware Proxy）:
#   Cloud Run Service の前段に立つ Google の認証プロキシ。
#   許可したユーザー（Google アカウント）だけがアプリにアクセスできる。
#   アプリ側に認証コードを書かなくても、IAP がログインを強制してくれる。
#
# 構成（ファイル分割）:
#   main.tf                - provider / API / プロジェクト情報 / IAP サービスエージェント
#   service-account.tf     - 実行用 Service Account と IAM
#   artifact-registry.tf   - コンテナイメージ置き場
#   cloud-run-service.tf   - Cloud Run Service（IAP 有効）
#   iap.tf                 - IAP のアクセス制御
# =============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    # iap_enabled / google_project_service_identity は google-beta 専用
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
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

# プロジェクト番号などを取得（IAP サービスエージェントのメール生成に使う）
data "google_project" "this" {
  project_id = var.project_id
}

# 必要な API
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",              # Cloud Run
    "artifactregistry.googleapis.com", # Artifact Registry
    "iam.googleapis.com",              # Service Account
    "iap.googleapis.com",              # Identity-Aware Proxy
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# -----------------------------------------------------------------------------
# IAP のサービスエージェントを明示的に作成
# IAP が Cloud Run を呼び出すための専用 SA（service-<番号>@gcp-sa-iap...）。
# API 有効化だけだと生成が遅延しIAMバインドで「存在しない」エラーになることがあるので、
# このリソースで確実に作ってから run.invoker を付与する（iap.tf 参照）。
# -----------------------------------------------------------------------------
resource "google_project_service_identity" "iap" {
  provider = google-beta
  project  = var.project_id
  service  = "iap.googleapis.com"

  depends_on = [google_project_service.apis]
}
