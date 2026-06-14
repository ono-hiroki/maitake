# =============================================================================
# cloud-run-job.tf - Cloud Run Job（バッチ実行のコンテナ）
# -----------------------------------------------------------------------------
# Cloud Run Job = リクエストを受けず「実行して完了する」バッチ向け Cloud Run。
# （対する Cloud Run Service は常駐してHTTPを受ける。cloudrun-service-iap で扱う）
#
# 注意: Job は作成時に「実在するイメージ」が必要。
#   学習用デフォルトは Google 公式のサンプルJobイメージ（実行すると完了する）。
#   本物の demo では Artifact Registry に push した自前イメージを使う。
#   image は lifecycle.ignore_changes にして、CI のデプロイで TF が上書きしないようにする。
# =============================================================================

resource "google_cloud_run_v2_job" "main" {
  name     = "${var.env}-${var.name}"
  location = var.region

  # デフォルト true。学習用に destroy できるよう false（実運用構成本番は true 推奨）
  deletion_protection = false

  template {
    task_count = 1

    template {
      service_account = google_service_account.job.email
      max_retries     = var.max_retries
      timeout         = var.task_timeout

      containers {
        image = var.image

        resources {
          limits = {
            cpu    = var.cpu
            memory = var.memory
          }
        }

        # サンプルJobイメージが参照する環境変数（タスク番号など）
        dynamic "env" {
          for_each = var.env_vars
          content {
            name  = env.key
            value = env.value
          }
        }
      }
    }
  }

  # 本物のイメージ更新は CI が行う。TF はイメージ/環境変数を追跡しない。
  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].image,
      template[0].template[0].containers[0].env,
      client,
      client_version,
    ]
  }

  depends_on = [
    google_project_service.apis,
    google_project_iam_member.job,
  ]
}
