# pubsub-minimal — Pub/Sub 単体の最小構成

Pub/Sub はメッセージングの土台: **publisher → topic → subscription → subscriber**。
Eventarc が裏で使っている仕組みを、単体で publish / pull して体感する。

## 作るもの

- `google_pubsub_topic`（送り先）
- `google_pubsub_subscription`（pull 型の受け口）

## 試す

```bash
terraform init && terraform apply

# メッセージを publish
gcloud pubsub topics publish min-pubsub \
  --message='{"hello":"demo"}' --project=your-project-id

# subscription から pull（--auto-ack で確認応答まで）
gcloud pubsub subscriptions pull min-pubsub-sub \
  --auto-ack --limit=5 --project=your-project-id
# → DATA 列に {"hello":"demo"} が見える

terraform destroy
```

## ポイント

- **topic と subscription は別物**: topic に publish、subscription から pull（または push）。
  1つの topic に複数 subscription をぶら下げて「同じメッセージを複数系統で受ける」もできる。
- `ack_deadline_seconds`: pull 後この秒数内に ack しないと再配信される（処理保証の仕組み）。
- Eventarc の GCS/Pub/Sub トリガーは、この topic+subscription を自動で作って配送に使っている。
  つまり `eventarc-minimal` や 07 本体の「裏側」がこれ。
