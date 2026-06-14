# =============================================================================
# cloudsql.tf - Cloud SQL インスタンス / データベース / ユーザー
# =============================================================================

# -----------------------------------------------------------------------------
# Cloud SQL インスタンス（PostgreSQL）
# - tier db-f1-micro: 最安の共有コア。学習用。
# - availability_type ZONAL: 単一ゾーン（REGIONAL=HAは共有コアでは不可、かつ高い）。
# - ipv4_enabled false + private_network: 外部IPを持たず内部IPのみ（VPC内部から接続）。
# - deletion_protection false: 学習用に destroy できるように。
# -----------------------------------------------------------------------------
resource "google_sql_database_instance" "main" {
  name             = "${var.env}-${var.instance_name}"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier              = "db-f1-micro"
    disk_type         = "PD_SSD"
    disk_size         = 10
    availability_type = "ZONAL"

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.main.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled = false # 学習用にバックアップ無効でコスト最小化
    }
  }

  deletion_protection = false

  # ピアリング接続が確立してから作る
  depends_on = [google_service_networking_connection.main]
}

# データベース（インスタンス内の論理DB）
resource "google_sql_database" "main" {
  name     = var.database_name
  instance = google_sql_database_instance.main.name
}

# -----------------------------------------------------------------------------
# DB ユーザー（実運用構成と同じ方式）
# - password には初回用のダミー値を入れる。本物は apply 後に gcloud で手動投入する。
# - lifecycle.ignore_changes = [password] で TF は password を追跡しない。
#   → 手動で本物に変えても TF はダミーに戻さないし、本物を state に書かない。
#   → 結果として「本物のパスワードは一度も Terraform / tfstate を通らない」。
# -----------------------------------------------------------------------------
resource "google_sql_user" "main" {
  name     = var.db_user
  instance = google_sql_database_instance.main.name
  password = var.db_password_placeholder

  lifecycle {
    ignore_changes = [password]
  }
}
