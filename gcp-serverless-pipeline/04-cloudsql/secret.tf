# =============================================================================
# secret.tf - Secret Manager（DB パスワードの「入れ物」だけ作る）
# -----------------------------------------------------------------------------
# 実運用構成と同じ方式: Terraform では Secret（入れ物）だけ作り、値（SecretVersion）は
# 作らない。本物のパスワードは apply 後に gcloud で手動投入する。
#   → 本物の値が tfstate に平文で残らない。
#
#   Secret（入れ物。ここで作る）─ SecretVersion（実際の値。TF 管理外で投入）
#
# アプリ（Cloud Run Job 等）は Secret Manager から値を読む想定。
# =============================================================================

resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.env}-${var.instance_name}-db-password"

  replication {
    auto {} # 自動レプリケーション（リージョン指定なし）
  }

  depends_on = [google_project_service.apis]
}

# 注意: google_secret_manager_secret_version はあえて作らない。
# secret_data に値を書くと tfstate に平文で入ってしまうため。
# 値の投入は apply 後に手動で（README 参照）:
#   echo -n "<本物のパスワード>" | gcloud secrets versions add \
#     sbx-demo-db-password --data-file=- --project=your-project-id
