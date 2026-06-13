# =============================================================================
# cloud-run-service.tf - Cloud Run Service（常駐 HTTP、IAP 有効）
# -----------------------------------------------------------------------------
# Cloud Run Service = HTTP リクエストを受け続ける常駐コンテナ（Web/API）。
# iap_enabled = true にすると、前段に IAP（認証プロキシ）が入る。
#
# 注意: Service は実在するイメージが必要 + コンテナは $PORT で待ち受ける必要がある。
#   学習用デフォルトは Google 公式のサンプル hello イメージ（$PORT で待ち受ける）。
#   本物の demo では Artifact Registry の自前イメージ（可視化アプリ）を使う。
# =============================================================================

resource "google_cloud_run_v2_service" "main" {
  provider = google-beta # iap_enabled が beta 専用フィールドのため
  name     = "${var.env}-${var.name}"
  location = var.region

  # 外部からの到達を許可（実際のアクセス可否は IAP が制御する）
  ingress     = "INGRESS_TRAFFIC_ALL"
  iap_enabled = true

  # デフォルト true。学習用に destroy できるよう false（実運用構成本番は true 推奨）
  deletion_protection = false

  template {
    service_account = google_service_account.service.email

    scaling {
      min_instance_count = 0 # 0 にするとアイドル時にインスタンス0=課金なし
      max_instance_count = 3
    }

    containers {
      image = var.image

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }
    }
  }

  # イメージ/環境変数などの「中身」は CI のデプロイに任せ、TF は追跡しない
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      template[0].containers[0].env,
      client,
      client_version,
    ]
  }

  depends_on = [
    google_project_service.apis,
    google_project_iam_member.service,
  ]
}
