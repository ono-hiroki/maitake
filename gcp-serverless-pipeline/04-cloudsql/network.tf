# =============================================================================
# network.tf - VPC / Private Service Access（01-network 相当の部分）
# -----------------------------------------------------------------------------
# 重要な概念: Private Service Access（プライベートサービスアクセス）
#   Cloud SQL は Google 管理のVPCで動く。自分のVPCから内部IPで繋ぐには、
#   「VPCピアリング用のIP範囲を予約」→「Service Networking 接続を確立」する。
#   これにより Cloud SQL に外部IPを持たせず、VPC内部から安全に接続できる。
#   ※ Private Service Access に必要なのは VPC と予約IP範囲だけ。サブネットは不要
#     （サブネットは VM/Cloud Run を配置するためのもの）。
# =============================================================================

# -----------------------------------------------------------------------------
# このモジュール専用の VPC（01-network とは別物。単体で完結させるため自作）
# Cloud SQL の Private Service Access はサブネット不要なので VPC のみ作る。
# -----------------------------------------------------------------------------
resource "google_compute_network" "main" {
  name                    = "${var.env}-${var.vpc_name}"
  auto_create_subnetworks = false
  description             = "GCPサーバーレスパイプライン学習 04-cloudsql 専用 VPC"

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# Private Service Access のための IP 範囲予約
# Cloud SQL 等の Google マネージドサービスに割り当てる内部IP範囲を予約する。
# -----------------------------------------------------------------------------
resource "google_compute_global_address" "private_ip_range" {
  name          = "${var.env}-${var.vpc_name}-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
  description   = "Cloud SQL 用に予約した内部IP範囲"
}

# -----------------------------------------------------------------------------
# Service Networking 接続（VPCピアリングの確立）
# 予約したIP範囲を使って、自分のVPCと Google のサービスVPCをピアリングする。
# deletion_policy = "ABANDON": destroy時に接続削除でハマりやすいので放棄する。
# -----------------------------------------------------------------------------
resource "google_service_networking_connection" "main" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
  deletion_policy         = "ABANDON"

  depends_on = [google_project_service.apis]
}
