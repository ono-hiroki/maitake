# cloudrun-service-iap — Cloud Run Service / IAP 認証 / Service Account

Cloud Run Service（HTTP を受け続ける常駐アプリ）と IAP 認証の最小構成。
Cloud Run Job との対比で **Service** と **IAP** を学ぶ。

## 学ぶこと

- **Cloud Run Service vs Job**:
  - Service = 常駐して HTTP を受け続ける（Web/API）。`$PORT` で待ち受ける
  - Job = 実行して完了するバッチ（05）
- **IAP（Identity-Aware Proxy）**: アプリ前段の認証プロキシ。許可した Google アカウント
  だけがアクセスできる。アプリ側に認証コードを書かなくてよい
- **IAP を効かせる2つの IAM**:
  1. IAP サービスエージェントに `run.invoker`（IAP→Cloud Run の転送許可）
  2. 許可ユーザーに `iap.httpsResourceAccessor`（このユーザーが通過できる）
- **min_instances=0**: アイドル時にインスタンス0 → リクエストが来た時だけ起動（コスト最小）

## ファイル構成

| ファイル | 内容 |
|---------|------|
| `main.tf` | provider / API / project データ / IAP サービスエージェント |
| `service-account.tf` | SA + IAM |
| `artifact-registry.tf` | Docker リポジトリ |
| `cloud-run-service.tf` | Cloud Run Service（`iap_enabled = true`） |
| `iap.tf` | IAP のアクセス制御（2種の IAM） |

## 作成されるリソース

| リソース | 名前 | 説明 |
|---------|------|------|
| API | run / artifactregistry / iam / iap | 4つ有効化 |
| Service Account | `sbx-web-run@...` | サービス実行用 |
| Artifact Registry | `sbx-web` | DOCKER（今回は空） |
| Cloud Run Service | `sbx-web` | hello イメージ, IAP 有効 |
| IAM (run.invoker) | — | IAP サービスエージェントに付与 |
| IAM (iap.httpsResourceAccessor) | — | `iap_members` のユーザーに付与 |

## 実行手順

```bash
terraform init
terraform plan
terraform apply

# サービス URL を取得
terraform output -raw service_uri
# → ブラウザで開くと Google ログインを求められ（IAP）、
#   iap_members に入れたアカウントでのみ hello 画面が見える。
#   許可していないアカウント / 未ログインだと 403。

# 認証なしで curl すると弾かれることを確認（IAP が効いている証拠）
curl -s -o /dev/null -w "%{http_code}\n" "$(terraform output -raw service_uri)"   # 302/403 など

# 片付け
terraform destroy
```

> 🔑 IAP は「アプリの前で Google ログインを強制し、許可リストのユーザーだけ通す」仕組み。
> 組織（example.com）内アカウントならそのまま通る。組織外ユーザーを通すには
> カスタム OAuth クライアントの手動設定が別途必要（実運用構成 CLAUDE.md の注記参照）。

## トラブルシュート：IAP で「You don't have access」(403) が続く

実際にハマったので記録。**認証は通る（ページに自分のメールが出る）のに 403** という状況。

### 切り分けの考え方（権限は2系統）

```
① 誰がアプリを"開ける"か（ブラウザ閲覧）= IAP 認可
   - ユーザーに roles/iap.httpsResourceAccessor   （iap.tf）
   - IAPエージェントに roles/run.invoker          （iap.tf）
② アプリ(コンテナ)が"実行中に何をできる"か = Service Account のロール（service-account.tf）
   - logging / monitoring / bigquery …  ← ブラウザ閲覧には無関係！
```

「ブラウザで見えない」は①の問題。②（SA ロール）をいくらいじっても直らない。

### 確認コマンド

```bash
# ① IAP IAM が付いているか（サーバ側の実体）
gcloud iap web get-iam-policy --resource-type=cloud-run \
  --service=sbx-web --region=asia-northeast1 --project=your-project-id

# ② 拒否理由を Audit Logs で見る（ここが決定打）
gcloud logging read 'protoPayload.serviceName="iap.googleapis.com"' \
  --project=your-project-id --limit=5 --freshness=15m \
  --format="value(timestamp, protoPayload.authorizationInfo[0].granted, \
    protoPayload.requestMetadata.requestAttributes.auth.principal, \
    protoPayload.requestMetadata.requestAttributes.path)"
```

### ログの読み方

- `authorizationInfo.granted=false` + `permission=iap.webServiceVersions.accessViaIAP`
- **`auth.principal` が空** → IAP にセッション（認証情報）が届いていない＝「IAM 不足」ではなく
  **認証セッション層の問題**。原因は次のどちらかが多い:
  1. **ブラウザのサードパーティ Cookie ブロック**（2026 の Chrome は既定でブロック）。
     → サイトに対し 3rd-party Cookie を許可して再アクセス
  2. **組織のコンテキストアウェアアクセス**（未管理端末を弾く）。`device_state: Unknown` が手掛かり。
     → 組織管理者に確認、または管理対象端末/社内ネットから

### 切り分け：アプリ本体が生きているかの確認（IAP を一時 OFF）

```bash
gcloud run services update sbx-web --region=asia-northeast1 --no-iap
gcloud run services add-iam-policy-binding sbx-web --region=asia-northeast1 \
  --member=allUsers --role=roles/run.invoker        # ⚠️ 一時的に公開。確認後は必ず戻す
curl -s -o /dev/null -w "%{http_code}\n" "$(終点URL)"  # 200 ならアプリは正常
# 戻す: --iap を有効化し allUsers バインドを削除
gcloud run services update sbx-web --region=asia-northeast1 --iap
gcloud run services remove-iam-policy-binding sbx-web --region=asia-northeast1 \
  --member=allUsers --role=roles/run.invoker
```

> 教訓: 「設定したのに 403」はまず **Audit Logs の `authorizationInfo` と `auth.principal`** を見る。
> principal が空なら IAM ではなく**認証セッション層（Cookie/組織ポリシー）**を疑う。Terraform の外。

## 実運用構成との違い

- 実運用構成は VPC 接続（Cloud SQL 参照）、GCS バケットへの IAM、Secret 注入、複数ロールを設定。
  ここは単体完結のため VPC 接続・GCS・Secret は省略し、IAP と Service の本質に集中。
- 実運用構成のイメージは初回 nginx 仮イメージ→CI が差し替え。ここは公式 hello イメージを既定に。
- 実運用構成は `project_number` を変数で受け取る。ここは `data.google_project` で自動取得。
