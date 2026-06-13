output "instance_name" {
  description = "Cloud SQL インスタンス名"
  value       = google_sql_database_instance.main.name
}

output "instance_connection_name" {
  description = "接続名（project:region:instance 形式。Cloud SQL Proxy 等で使う）"
  value       = google_sql_database_instance.main.connection_name
}

output "private_ip_address" {
  description = "Cloud SQL の内部 IP アドレス"
  value       = google_sql_database_instance.main.private_ip_address
}

output "database_name" {
  description = "作成した論理データベース名"
  value       = google_sql_database.main.name
}

output "db_user" {
  description = "DB ユーザー名"
  value       = google_sql_user.main.name
}

output "secret_id" {
  description = "パスワードを保存した Secret Manager の secret ID"
  value       = google_secret_manager_secret.db_password.secret_id
}
