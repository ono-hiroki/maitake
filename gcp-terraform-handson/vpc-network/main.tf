# =============================================================================
# vpc-network: VPC / Subnet / Firewall
# -----------------------------------------------------------------------------
# GCP ネットワークの最小構成を学ぶ。
#
# GCP のネットワーク階層:
#   VPC (グローバル) ─┬─ Subnet (リージョン単位) ── ここに VM/Cloud SQL などが乗る
#                     └─ Firewall (VPC 全体に適用、ルールで許可/拒否)
# AWS と違い VPC はグローバル、サブネットがリージョンに紐づくのが特徴。
# =============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# -----------------------------------------------------------------------------
# 必要な API の有効化
# GCP は各サービスの API をプロジェクトごとに有効化しないと使えない。
# 実運用では root の main.tf で全 API をまとめて google_project_service
# で管理している。この学習リポジトリでは「モジュールが必要な API を自分で有効化」
# する方針にして、サービスと API の対応を分かりやすくする。
#
# disable_on_destroy = false がポイント:
#   terraform destroy しても API は無効化しない。API を無効化すると同プロジェクト内の
#   他リソースを巻き込んで壊す恐れがあるため、実運用構成もこの設定にしている。
# -----------------------------------------------------------------------------
resource "google_project_service" "compute" {
  project = var.project_id
  service = "compute.googleapis.com" # VPC / Subnet / Firewall に必要

  disable_on_destroy = false
}

# -----------------------------------------------------------------------------
# VPC ネットワーク
# auto_create_subnetworks = false にすると「カスタムモード VPC」になり、
# サブネットを自分で明示的に定義できる（本番ではこちらが推奨）。
# true だと全リージョンに自動でサブネットが作られる（auto モード）。
# -----------------------------------------------------------------------------
resource "google_compute_network" "main" {
  name                    = "${var.env}-${var.vpc_name}"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL" # ルートの伝播範囲。REGIONAL or GLOBAL
  description             = "GCP Terraform ハンズオン 学習用 VPC"

  # API が有効になってから作成する
  depends_on = [google_project_service.compute]
}

# -----------------------------------------------------------------------------
# サブネット（リージョン単位）
# ip_cidr_range でプライベート IP の範囲を決める。ここに各リソースが配置される。
# -----------------------------------------------------------------------------
resource "google_compute_subnetwork" "main" {
  name          = "${var.env}-${var.vpc_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.main.id

  # VM が外部 IP なしで Google API にアクセスできるようにする（Cloud SQL 等で有用）
  private_ip_google_access = true
}

# -----------------------------------------------------------------------------
# Firewall: VPC 内部の通信を許可するルール
# GCP の Firewall は VPC に対して設定し、source_ranges で送信元を絞る。
# 実運用では Cloud SQL (PostgreSQL=5432) の内部通信用に使っている。
# -----------------------------------------------------------------------------
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.env}-${var.vpc_name}-allow-internal"
  network = google_compute_network.main.id

  # PostgreSQL ポート
  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  # ping 用（疎通確認に便利）
  allow {
    protocol = "icmp"
  }

  # サブネット内部からの通信のみ許可
  source_ranges = [var.subnet_cidr]
  priority      = 65534 # 数値が小さいほど優先。65534 は低優先（デフォルト許可ルール相当）
}
