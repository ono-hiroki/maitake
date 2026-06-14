# =============================================================================
# iap.tf - IAP（Identity-Aware Proxy）のアクセス制御
# -----------------------------------------------------------------------------
# IAP を効かせるには2つの IAM 設定が要る:
#   1. IAP サービスエージェントに「Cloud Run を呼び出す権限」(run.invoker) を付与
#      → IAP が認証OKのリクエストを Cloud Run に転送できるようにする
#   2. アクセスを許可したいユーザー/グループに iap.httpsResourceAccessor を付与
#      → このユーザーだけが IAP のログインを通過してアプリに到達できる
# =============================================================================

# 1. IAP サービスエージェント（service-<番号>@gcp-sa-iap...）に run.invoker
resource "google_cloud_run_v2_service_iam_member" "iap_invoker" {
  project  = var.project_id
  location = google_cloud_run_v2_service.main.location
  name     = google_cloud_run_v2_service.main.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_project_service_identity.iap.email}"
}

# 2. 許可ユーザーに IAP アクセス権（iap.httpsResourceAccessor）
#    var.iap_members に列挙した principal だけがアプリにアクセスできる。
resource "google_iap_web_cloud_run_service_iam_member" "members" {
  for_each = toset(var.iap_members)

  project                = var.project_id
  location               = google_cloud_run_v2_service.main.location
  cloud_run_service_name = google_cloud_run_v2_service.main.name
  role                   = "roles/iap.httpsResourceAccessor"
  member                 = each.value
}
