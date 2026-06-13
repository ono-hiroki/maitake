# 08-cicd — Workload Identity Federation（鍵レス認証）

GitHub Actions が **サービスアカウントキー(JSON)を
一切持たずに** GCP に認証してデプロイできるようにする仕組み。学習ロードマップの最終回。

## なぜ鍵レスか

| | SA キー(JSON) 方式 | WIF（鍵レス） |
|---|---|---|
| 保管 | GitHub Secrets に長命の鍵を置く | 何も保管しない |
| 漏洩リスク | 漏れたら無効化まで使い放題 | トークンは短命・リポジトリ限定 |
| ローテーション | 手動で大変 | 不要 |

## 認証の流れ

```
GitHub Actions 実行
  → GitHub が OIDC トークン発行（repo/owner/branch の claim 入り）
    → GCP: Workload Identity Pool/Provider が検証
        ① issuer は token.actions.githubusercontent.com か
        ② attribute_condition: repository_owner は一致するか
          → ③ principalSet バインド: この repository は SA を impersonate してよいか
            → 短命の GCP クレデンシャル取得 → push / deploy
```

## AWS との対応（IAM OIDC Provider + AssumeRoleWithWebIdentity と同じ発想）

WIF は AWS の「GitHub OIDC → IAM Role を AssumeRoleWithWebIdentity」とやりたいことは同じ。
骨格（外部 OIDC トークン → 検証 → 短命クレデンシャルに交換）は完全に対応する。

| 概念 | AWS | GCP（WIF） |
|---|---|---|
| issuer を信頼する登録 | IAM **OIDC Identity Provider** | **Workload Identity Pool Provider**（`issuer_uri`） |
| 受け入れ条件（誰のトークンか） | Role 信頼ポリシーの `Condition`（`sub`/`aud`） | `attribute_condition`（owner）+ `principalSet`（repo） |
| 成り代わる先の ID + 権限 | **IAM Role**（信頼+権限ポリシー） | **Service Account**（+ project IAM ロール） |
| トークン交換 API | `sts:AssumeRoleWithWebIdentity` | **STS** トークン交換（`sts.googleapis.com`） |
| 結果 | 短命の STS 一時クレデンシャル | 短命の SA アクセストークン |

### 構造の違い

- **AWS は 1 つの Role に「信頼」と「権限」が同居**する。
- **GCP は役割が分割**される:
  - 「誰が成り代わってよいか」= `workloadIdentityUser` バインド（principalSet → SA）… ≒ AWS 信頼ポリシー
  - 「その ID は何ができるか」= SA への project IAM ロール … ≒ AWS 権限ポリシー
  - だから GCP は Pool / Provider / SA と部品が多い（08 のリソース数が多めに見える理由）。
- 補足: GCP も principalSet に**直接ロールを付与**する方式（direct resource access）があり、
  これは AWS の「Role = ID + 権限」により近い。ただし SA を impersonate する方式が
  一般的なので 08（と実運用構成）はそちらを採用。

## 学ぶこと

- **Pool / Provider**: 外部 ID の受け入れ口と検証ルール（attribute_mapping / condition）
- **principalSet://**: 「Pool を通った特定属性の外部 ID」を IAM の member に書く WIF 特有の形式
- **impersonation**: 外部 ID が SA として振る舞う（`roles/iam.workloadIdentityUser`）
- **actAs（serviceAccountUser）**: デプロイ時にランタイム SA を指定するのに必要。
  無いと `iam.serviceaccounts.actAs denied` で落ちる定番ハマり
- **多層防御**: condition（owner）× principalSet（repo）× SA ロール（操作）の3段で絞る

## ファイル構成

| ファイル | 内容 |
|---------|------|
| `main.tf` | provider + API（iam / iamcredentials / sts） |
| `wif.tf` | Workload Identity Pool + OIDC Provider |
| `service-account.tf` | CI/CD SA + ロール + actAs + WIF↔SA バインド |

## 実行手順

```bash
# terraform.tfvars の github_owner / github_repository を自分のものに変更してから
terraform init
terraform plan
terraform apply

# GitHub Actions 側の設定値を取得
terraform output -raw workload_identity_provider
terraform output -raw cicd_service_account
```

### GitHub Actions 側（参考: .github/workflows/deploy.yml）

```yaml
permissions:
  contents: read
  id-token: write   # ← OIDC トークン発行に必須

steps:
  - uses: google-github-actions/auth@v2
    with:
      workload_identity_provider: <output: workload_identity_provider>
      service_account: <output: cicd_service_account>
  # 以降のステップは SA として gcloud / docker push / deploy ができる
```

> すぐ試せるサンプルを [`github-actions-example/wif-check.yml`](./github-actions-example/wif-check.yml)
> に置いてある。`<...>` を `terraform output` の値に置き換えて自分のリポジトリの
> `.github/workflows/` にコミット → Actions タブから手動実行すれば、SAキー無しで認証できる。

## ハマりどころ: Pool/Provider は削除後 30 日間 ID が予約される

`terraform destroy` しても Pool/Provider は**論理削除（soft delete）**で 30 日残る。
同名で再 apply すると `409 already exists` になる。対処:

```bash
# 復活させて使う
gcloud iam workload-identity-pools undelete sbx-demo-github --location=global --project=your-project-id
# または名前を変えて作る（tfvars の name や env を変更）
```

## コスト

WIF / SA / IAM はすべて無料。destroy を急ぐ必要はない（上記 soft delete の都合上、
むしろ消さずに置いておく方が再学習しやすい）。

## 実運用構成との違い

- 実運用構成はデプロイ先 SA（Cloud Run Job の SA）を変数で受け取って actAs を付与。
  ここは単体完結のためデモ用ランタイム SA をモジュール内で作成。
- 複数リポジトリから使う場合は、リポジトリごとに別々の Pool + SA を分けることが多い。
  ここでは1組のみ。
