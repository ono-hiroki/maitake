# =============================================================================
# 02-impersonated-apply: SA を impersonate して apply する（個人権限を使わない）
# -----------------------------------------------------------------------------
# 目的: 「provider の HCL を一切変えずに」環境変数だけで impersonate へ切り替わることを体感する。
#
#   export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT=lab-tf-runner@my-sandbox.iam.gserviceaccount.com
#
# この変数を立てて apply すると、下の provider は無改造のまま SA の権限で動く。
# 確認は data.google_client_openid_userinfo（terraform の「今の自分」を返す = whoami）:
#   - 変数なし → あなた個人のメール
#   - 変数あり → SA のメール（= なりすませている証拠）
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

# provider には impersonate を書いていない。切替は環境変数に任せる。
provider "google" {
  project = var.project_id
  region  = var.region
}

# --- 別解（参考）----------------------------------------------------------
# 環境変数ではなく HCL に直書きしたい場合はこう書く:
#
#   provider "google" {
#     project                     = var.project_id
#     region                      = var.region
#     impersonate_service_account = "lab-tf-runner@my-sandbox.iam.gserviceaccount.com"
#   }
#
# ただし backend(GCS) 側にも別途 impersonate 設定が要る点に注意。
# 環境変数なら provider と backend を一括で切り替えられるので、このラボは環境変数方式。
# --------------------------------------------------------------------------

# whoami: terraform が今どの ID で動いているかを返す data source。
# 環境変数の有無で email 出力が「あなた」⇄「SA」に変わる。
data "google_client_openid_userinfo" "me" {}

# impersonate できている証拠づくり用のバケット。
# 作成には storage.admin が要る → これは 01 で SA に付けたロール。
# つまり「SA の権限で作られている」ことの確認も兼ねる。
resource "google_storage_bucket" "lab" {
  name                        = "${var.project_id}-impersonation-lab"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true

  labels = {
    lab = "impersonation"
  }
}

output "whoami_email" {
  description = "terraform が今使っている ID。impersonate 中は SA のメールになる。"
  value       = data.google_client_openid_userinfo.me.email
}

output "bucket_name" {
  value = google_storage_bucket.lab.name
}
