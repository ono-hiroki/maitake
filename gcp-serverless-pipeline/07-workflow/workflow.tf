# =============================================================================
# workflow.tf - Workflows 本体 + 実行用 Service Account
# -----------------------------------------------------------------------------
# Workflows = YAML で定義した処理を順に実行するサーバレスのオーケストレータ。
# ここでは「ログ出力 → Cloud Run Job を実行 → 結果ログ」を行う（workflow.yaml）。
# =============================================================================

resource "google_service_account" "workflow" {
  account_id   = "${var.env}-${var.name}-wf"
  display_name = "Workflows 実行用 SA (07-workflow)"
}

resource "google_project_iam_member" "workflow" {
  for_each = toset([
    "roles/run.developer",     # Cloud Run Job を overrides 付きで実行するのに必要
    "roles/logging.logWriter", # sys.log 出力用
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.workflow.email}"
}

resource "google_workflows_workflow" "main" {
  name                = "${var.env}-${var.name}"
  region              = var.region
  description         = "GCS 投入ファイルを Cloud Run Job で処理する"
  service_account     = google_service_account.workflow.email
  call_log_level      = "LOG_ALL_CALLS"
  deletion_protection = false # デフォルト true。学習用に destroy 可

  # workflow.yaml をテンプレートとして読み込み、Job ID を埋め込む
  source_contents = templatefile("${path.module}/workflow.yaml", {
    cloud_run_job_id = google_cloud_run_v2_job.main.id
  })

  depends_on = [google_project_iam_member.workflow]
}
