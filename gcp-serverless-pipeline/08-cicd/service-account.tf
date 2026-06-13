# =============================================================================
# service-account.tf - CI/CD 用 SA / IAM ロール / WIF↔SA バインディング
# -----------------------------------------------------------------------------
# GitHub Actions は WIF を通過した後、「この SA として」GCP を操作する（impersonation）。
# つまり CI/CD に許す操作 = この SA に付けるロール、で制御できる。
# =============================================================================

# CI/CD（GitHub Actions）が名乗る SA
resource "google_service_account" "cicd" {
  account_id   = "${var.env}-${var.name}-cicd"
  display_name = "CI/CD 用 SA (GitHub Actions)"
  description  = "GitHub Actions が WIF 経由で impersonate する SA"
}

# CI/CD に許す操作（実運用構成と同じ: イメージ push + Cloud Run デプロイ）
resource "google_project_iam_member" "cicd" {
  for_each = toset([
    "roles/artifactregistry.writer", # Artifact Registry へイメージ push
    "roles/run.developer",           # Cloud Run Job/Service のデプロイ
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# -----------------------------------------------------------------------------
# デプロイ先のランタイム SA（actAs のデモ用にこのモジュール内で作る）
# Cloud Run をデプロイする際、CI/CD SA は「ランタイム SA を指定して」サービスを作る。
# 他人（ランタイム SA）を指定する操作には iam.serviceAccountUser（actAs）が必要。
# これが無いと deploy 時に "Permission iam.serviceaccounts.actAs denied" になる。
# -----------------------------------------------------------------------------
resource "google_service_account" "runtime" {
  account_id   = "${var.env}-${var.name}-runtime"
  display_name = "デプロイ対象のランタイム SA（actAs デモ用）"
}

resource "google_service_account_iam_member" "cicd_act_as_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cicd.email}"
}

# -----------------------------------------------------------------------------
# WIF ↔ SA バインディング（鍵レス認証の最後のピース）
# 「Pool を通過した外部 ID のうち、attribute.repository が指定リポジトリのものだけ、
#  この SA を impersonate してよい」という許可。
# member の principalSet:// 形式が WIF 特有の書き方:
#   principalSet://iam.googleapis.com/<pool名>/attribute.repository/<owner/repo>
# -----------------------------------------------------------------------------
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.cicd.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}
