# 07-workflow — Eventarc / Workflows（イベント駆動）

**データフロー全体をつなぐ統合回**。
単体完結のため、入力バケットと呼び出し先 Cloud Run Job も含めて作る。

## 実現する流れ（demo の心臓部）

```
GCS にファイル投入
  → Eventarc が finalized(作成完了) イベントを検知
    → Workflows を起動
      → Workflows が Cloud Run Job を実行（ファイル名を env で渡す）
```

## 学ぶこと

- **Eventarc**: 「○○が起きたら△△を呼ぶ」イベントルーター。GCS トリガーは裏で **Pub/Sub** を使う
- **Workflows**: 複数 API 呼び出しを **YAML** で順に実行するサーバレスのオーケストレータ
- **イベント駆動は登場人物（SA / サービスエージェント / IAM）が多い**:
  - Workflows 実行 SA: `run.developer`（Job実行） + `logging.logWriter`
  - Eventarc トリガー SA: `eventarc.eventReceiver` + `workflows.invoker`
  - Eventarc サービスエージェント: `eventarc.serviceAgent`
  - GCS サービスエージェント: `pubsub.publisher`（GCS→Pub/Sub通知のため）
- **templatefile**: `workflow.yaml` に Terraform から Job ID を埋め込む
- **Workflows の式記法**: `$${...}` が実行時の式、`${...}` は Terraform の埋め込み

## ファイル構成

| ファイル | 内容 |
|---------|------|
| `main.tf` | provider(google+beta) / API / project |
| `storage.tf` | 入力 GCS バケット + GCS SA に pubsub.publisher |
| `cloud-run-job.tf` | 起動される Cloud Run Job + SA |
| `workflow.tf` | Workflows + 実行 SA + IAM |
| `eventarc.tf` | Eventarc トリガー + SA + サービスエージェント権限 |
| `workflow.yaml` | Workflows の処理定義 |

## 実行手順

```bash
terraform init
terraform plan
terraform apply   # Eventarc/サービスエージェントの伝播で時間がかかる場合あり

# 動作確認: 入力バケットにファイルを置く → ジョブが起動するか
BUCKET=$(terraform output -raw input_bucket)
echo "hello demo $(date)" > /tmp/sample.txt
gcloud storage cp /tmp/sample.txt gs://$BUCKET/ --project=your-project-id

# 少し待ってから Workflows の実行履歴を見る
WF=$(terraform output -raw workflow_name)
gcloud workflows executions list $WF --location=asia-northeast1 --project=your-project-id --limit=3
# Cloud Run Job の実行履歴も増えているはず
gcloud run jobs executions list --job=$(terraform output -raw job_name) \
  --region=asia-northeast1 --project=your-project-id --limit=3

# 片付け
terraform destroy
```

> 💡 `apply` 直後はサービスエージェントの権限伝播待ちで、最初の数分はトリガーが発火しない/
> Workflows 起動が失敗することがある。数分待って再度ファイルを置くと安定する。

### ハマりどころ: Eventarc Service Agent の権限伝播

apply 時に次のエラーが出ることがある:

```
Error creating Trigger: Error 400: Permission denied while using the Eventarc Service Agent.
If you recently started to use Eventarc, it may take a few minutes ...
```

これは `eventarc.serviceAgent` ロールをサービスエージェントに付与した**直後**にトリガーを作ると、
権限の伝播が間に合わず弾かれるため。対策として `time_sleep`（120秒待機）を挟んでいる:

```hcl
resource "time_sleep" "wait_for_eventarc_agent" {
  depends_on      = [google_project_iam_member.eventarc_service_agent]
  create_duration = "120s"
}
# trigger 側で depends_on = [time_sleep.wait_for_eventarc_agent]
```

> 「IaC で “待つ” を表現する」定番テク。手動なら「数分待って再 apply」でも解決する
> （IAM 付与は冪等なので、失敗した apply を再実行すれば伝播済みで通ることが多い）。

## コスト注意

- GCS / Workflows / Eventarc / Cloud Run Job はいずれも実行・保存量ベースでごく少額。
- 放置リスクは低いが、学習後は `terraform destroy` で片付け推奨。

## 実運用構成との違い

- 実運用構成は入力バケットや Cloud Run Job を別モジュールから受け取る（`input_bucket_name`/`cloud_run_job_id` 変数）。
  ここは単体完結のため、バケットも Job もこのモジュール内で作成。
- 実運用構成の `project_number` は変数。ここは `data.google_project` で自動取得。
- workflow.yaml の処理内容は実運用構成とほぼ同一（ログ → Job 実行 → 結果ログ）。
