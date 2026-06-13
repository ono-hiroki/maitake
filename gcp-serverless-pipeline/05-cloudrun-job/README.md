# 05-cloudrun-job — Cloud Run Job / Artifact Registry / Service Account

バッチ処理の本体。
データフロー上の位置: `GCS → Eventarc → Workflows →【Cloud Run Job】→ Cloud SQL / BigQuery`

## 学ぶこと

- **Service Account（SA）**: ワークロードが「誰として」API を呼ぶかの機械アカウント
- **最小権限の IAM**: ジョブに必要なロールだけを `google_project_iam_member` で付与
- **Artifact Registry**: マネージドな Docker イメージ置き場。CI が push し Cloud Run が pull
- **Cloud Run Job**: 「実行して完了する」バッチ向け Cloud Run（常駐の Service とは別物）
- **image の ignore_changes**: イメージ更新は CI に任せ、TF は追跡しない運用パターン

## ファイル構成

| ファイル | 内容 |
|---------|------|
| `main.tf` | provider + API 有効化 |
| `service-account.tf` | SA + IAM ロール |
| `artifact-registry.tf` | Docker リポジトリ |
| `cloud-run-job.tf` | Cloud Run Job |

## 作成されるリソース

| リソース | 名前 | 説明 |
|---------|------|------|
| API | run / artifactregistry / iam | 3つ有効化 |
| Service Account | `sbx-demo-job@...` | ジョブ実行用 |
| IAM | logging / monitoring / bigquery×2 | SA に付与 |
| Artifact Registry | `sbx-demo` | DOCKER, 最新5個保持 |
| Cloud Run Job | `sbx-demo` | サンプルJobイメージ |

## 実行手順

```bash
terraform init
terraform plan
terraform apply

# 確認: ジョブ一覧
gcloud run jobs list --project=your-project-id --region=asia-northeast1
# ジョブを実行して完了を見る（サンプルイメージはタスクを出力して終了する）
gcloud run jobs execute sbx-demo --project=your-project-id --region=asia-northeast1 --wait
# Artifact Registry リポジトリ確認
gcloud artifacts repositories list --project=your-project-id --location=asia-northeast1

# 片付け
terraform destroy
```

### サンプルJobイメージで「確率失敗 → 自動リトライ」を観察する

デフォルトの公式サンプルイメージ（`us-docker.pkg.dev/cloudrun/container/job`）は次の環境変数を読む:

| 環境変数 | 意味 |
|---------|------|
| `FAIL_RATE` | 各タスクが失敗する確率（`0.0`〜`1.0`） |
| `SLEEP_MS` | 各タスクのスリープ時間（処理時間の模擬） |

`FAIL_RATE` で確率的に失敗させ、`max_retries`（既定3）でリトライされる様子を観察できる。

```bash
# env と tasks を設定（※ env は ignore_changes 対象なので gcloud で直接更新する）
gcloud run jobs update sbx-demo --region=asia-northeast1 --project=your-project-id \
  --update-env-vars FAIL_RATE=0.5,SLEEP_MS=1000 --tasks=4

# 実行
gcloud run jobs execute sbx-demo --region=asia-northeast1 --project=your-project-id --wait

# 実行ごとの成功/失敗/リトライ回数を見る
EXEC=$(gcloud run jobs executions list --job=sbx-demo \
  --region=asia-northeast1 --project=your-project-id --format="value(name)" --limit=1)
gcloud run jobs executions describe "$EXEC" --region=asia-northeast1 --project=your-project-id \
  --format="yaml(status.taskCount,status.succeededCount,status.failedCount,status.retriedCount)"
# 例: retriedCount: 1, succeededCount: 4 → 1タスクが失敗→リトライで成功、最終的に全成功
# max_retries を 0 にすると失敗が failedCount に残る
```

> 💡 ポイント: `env_vars` は `cloud-run-job.tf` で `ignore_changes` 対象。よって作成済みジョブには
> `terraform apply` で env を変えても反映されない（gcloud で更新するか destroy→apply が必要）。
> これは「中身の運用は TF 管理外」という設計の実例。

### 自前イメージを push する場合（任意）

```bash
# AR への認証設定（初回のみ）
gcloud auth configure-docker asia-northeast1-docker.pkg.dev
# ビルド & push
REPO=$(terraform output -raw artifact_registry_url)
docker build -t "$REPO/app:latest" .
docker push "$REPO/app:latest"
# その後 image 変数を自前イメージに変えて apply（または gcloud run jobs update）
```

## コスト注意

- Cloud Run Job は**実行した分だけ課金**（待機中は無料）。作っておくだけなら基本無料。
- Artifact Registry はイメージ保存量で少額課金。サンプルのみなら誤差。

## 実運用構成との違い

- 実運用構成はジョブを VPC 接続（`vpc_access`）して Cloud SQL に内部IPでアクセス + サブネット作成 +
  Secret Manager から DB パスワードを env 注入する。ここは単体完結のため VPC 接続と Secret 注入は省略。
- 実運用構成の IAM ロールは7種（cloudsql.client / bigquery×2 / datastore.user / logging / monitoring / aiplatform.user）。
  ここは代表例として logging / monitoring / bigquery×2 に絞る。
- 実運用構成のイメージは Artifact Registry の自前イメージ。ここは apply 成功のため公式サンプルJobイメージを既定に。
