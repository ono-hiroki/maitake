# =============================================================================
# artifact-registry.tf - コンテナイメージの置き場
# -----------------------------------------------------------------------------
# 05-application と同様、自前イメージの置き場。デモアプリ用に別リポジトリを用意する。
# （今回は Cloud Run Service のイメージに公式サンプルを使うため、この箱は空のまま）
# =============================================================================

resource "google_artifact_registry_repository" "main" {
  location      = var.region
  repository_id = "${var.env}-${var.name}"
  description   = "GCPサーバーレスパイプライン学習 demo-ui 用コンテナイメージ"
  format        = "DOCKER"

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
