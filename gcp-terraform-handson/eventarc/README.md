# eventarc-minimal — Eventarc 単体の最小構成

最小の「イベント → 自動起動」: **Pub/Sub トピックに publish → Eventarc → Workflow 起動**。
GCS も Cloud Run Job も使わない。Eventarc の本質だけを取り出した形。

## イベント源に Pub/Sub を使う理由

Eventarc のイベント源には GCS / Pub/Sub / Cloud Audit Logs などがある。GCS 源は
「GCS サービスエージェントに pubsub.publisher 付与」が追加で必要になる。Pub/Sub 源に
するとその一手間が不要になり、Eventarc の核（SA・サービスエージェント・トリガー・
伝播待ち）だけに集中できる。

## 作るもの

- Pub/Sub トピック（イベント源）
- 最小 Workflow（イベントを受けてログするだけ） + その SA
- Eventarc トリガー SA（`eventReceiver` + `workflows.invoker`）
- Eventarc サービスエージェント（`eventarc.serviceAgent`）
- `time_sleep`（権限伝播待ち 120s）
- Eventarc トリガー（type=messagePublished, transport=既存トピック, dest=Workflow）

## 試す

```bash
terraform init && terraform apply   # time_sleep で 2 分ほど待つ

# トピックに publish → トリガー → Workflow 起動
gcloud pubsub topics publish min-eventarc-topic \
  --message='{"hello":"eventarc"}' --project=your-project-id

# 少し待って Workflow 実行履歴を確認
gcloud workflows executions list min-eventarc-wf \
  --location=asia-northeast1 --project=your-project-id --limit=3

terraform destroy
```

## ポイント

- **`matching_criteria` の type** で「どのイベントか」を指定:
  - `google.cloud.pubsub.topic.v1.messagePublished`（ここ）
  - `google.cloud.storage.object.v1.finalized`（GCS をソースにする場合）
- **`transport.pubsub.topic`** で既存トピックを指定。省略すると Eventarc がトピックを自動生成。
- イベント駆動は最小でも **SA + サービスエージェント + 伝播待ち** が要る。
  「Eventarc は登場人物が多い」を最小構成でも体感できる。
- 宛先を Cloud Run Service にすれば HTTP で直接イベントを受け取れる。Cloud Run Job は
  HTTP を受けないため、Job を起動したい場合は Workflows（[`../workflows`](../workflows)）等で
  Jobs API を呼ぶ必要がある。
