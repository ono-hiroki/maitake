# =============================================================================
# wif.tf - Workload Identity Pool / OIDC Provider（鍵レス認証の核）
# -----------------------------------------------------------------------------
# Pool     = 外部 ID（GitHub 等）を受け入れる「入れ物」
# Provider = 「どこの誰のトークンを、どう検証して、どう GCP の属性に写すか」の定義
# =============================================================================

# -----------------------------------------------------------------------------
# Workload Identity Pool
# 注意: Pool/Provider は delete しても 30日間は「論理削除」状態で ID が予約される。
# destroy → 同名で再 apply すると 409 になるので、名前を変えるか undelete が必要（README参照）。
# -----------------------------------------------------------------------------
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "${var.env}-${var.name}-github"
  display_name              = "GitHub Actions Pool (${var.env})"
  description               = "GitHub Actions の OIDC トークンを受け入れる Pool"

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# OIDC Provider
# - issuer_uri: GitHub Actions のトークン発行元。ここを信頼する、という宣言
# - attribute_mapping: OIDC トークンの claim（assertion.*）を GCP 側の属性に写す
#     google.subject       ← assertion.sub        （例: repo:owner/repo:ref:refs/heads/main）
#     attribute.repository ← assertion.repository （例: owner/repo）
# - attribute_condition: 受け入れ条件。これが無いと「GitHub の全リポジトリ」の
#   トークンを受け入れてしまう。最低でも owner で絞るのが必須（実運用構成も同様）
# -----------------------------------------------------------------------------
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC Provider"
  description                        = "GitHub Actions の OIDC トークンを検証する Provider"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  # owner が一致するトークンだけ受け入れる（なりすまし防止の要）
  attribute_condition = "assertion.repository_owner == \"${var.github_owner}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}
