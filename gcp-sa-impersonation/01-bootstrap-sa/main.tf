# =============================================================================
# 01-bootstrap-sa: terraform 実行用 SA を「個人 ADC で」作る（ブートストラップ）
# -----------------------------------------------------------------------------
# 目的: impersonate の土台を 3 点セットで用意する。
#   ① tf-runner SA を作る              … なりすます相手
#   ② SA に作業ロールを付ける          … 実際に terraform で触る権限（ここでは storage.admin）
#   ③ 自分に tokenCreator を付ける      … 「この SA を借りてよい」という鍵
#
# このディレクトリだけは個人 ADC で apply する。理由は卵が先か鶏が先か:
#   impersonate したい → でも SA も tokenCreator もまだ無い → 失敗する
#   なので「SA を生む最初の一回」は個人権限で行うしかない。
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
  # ここには impersonate を付けない。個人 ADC のまま実行する（ブートストラップ）。
}

# impersonate（generateAccessToken）には iamcredentials API が必要。
resource "google_project_service" "iamcredentials" {
  project            = var.project_id
  service            = "iamcredentials.googleapis.com"
  disable_on_destroy = false
}

# ① terraform 実行用の SA。人ではなくプログラム用の Google アカウント。
resource "google_service_account" "tf_runner" {
  project      = var.project_id
  account_id   = var.runner_sa_id # → lab-tf-runner@<project>.iam.gserviceaccount.com
  display_name = "Lab Terraform Runner"
  description  = "gcp-sa-impersonation 用。人間は tokenCreator 経由で借りて使う。"
}

# ② SA に「terraform で触るぶん」のロールを付与。
#    このラボでは 02 で GCS バケットを作るので storage.admin だけ。
#    実務では使うサービス分（run/bigquery/eventarc/...）を並べることになる。
resource "google_project_iam_member" "tf_runner_roles" {
  for_each = toset(var.runner_sa_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.tf_runner.email}"
}

# ③ 自分（人間）に「この SA を impersonate してよい」権限を付与。
#    これが無いと環境変数を立てても "Permission denied on iamcredentials" になる。
resource "google_service_account_iam_member" "token_creator" {
  service_account_id = google_service_account.tf_runner.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = var.token_creator_member # 例: user:you@example.com
}

output "sa_email" {
  description = "02 で impersonate する SA のメール。次の export にそのまま使う。"
  value       = google_service_account.tf_runner.email
}

output "next_step" {
  description = "02 へ進む前に実行するコマンド"
  value       = <<-EOT
    # 1) impersonate できるか単体確認（成功すればトークンが返る）
    gcloud auth print-access-token \
      --impersonate-service-account=${google_service_account.tf_runner.email}

    # 2) terraform を impersonate モードに切り替え（provider も backend も尊重する変数）
    export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT=${google_service_account.tf_runner.email}

    # 3) ../02-impersonated-apply へ移動して apply
  EOT
}
