# =============================================================================
# artifact-registry.tf - コンテナイメージの置き場（Docker リポジトリ）
# -----------------------------------------------------------------------------
# Artifact Registry = GCP のマネージドなアーティファクト（Docker イメージ等）置き場。
# CI でビルドしたイメージをここに push し、Cloud Run がここから pull する。
#   イメージURI: ${region}-docker.pkg.dev/${project}/${repo}/イメージ名:タグ
# =============================================================================

resource "google_artifact_registry_repository" "main" {
  location      = var.region
  repository_id = "${var.env}-${var.name}"
  description   = "GCP Terraform ハンズオン 用コンテナイメージ"
  format        = "DOCKER"

  # 古いイメージを自動削除するクリーンアップポリシー（最新N個だけ残す）
  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "keep-recent-images"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }

  depends_on = [google_project_service.apis]
}
