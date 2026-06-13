# 07-workflow の技術要素を単体・最小構成で試す

07-workflow は「GCS → Eventarc → Workflows → Cloud Run Job」と要素が多い。
ここでは**各要素を最小構成で1つずつ**触って理解するための独立モジュールを置く。

| ディレクトリ | 要素 | 最小構成でやること |
|-------------|------|------------------|
| `workflows-minimal` | Workflows | 手動実行する超小さい Workflow（引数を受けてログ＆返す） |
| `pubsub-minimal`    | Pub/Sub  | トピック + サブスクリプション（publish して pull） |
| `eventarc-minimal`  | Eventarc | Pub/Sub メッセージ → Workflow 起動（最小のイベント連携） |

※ GCS 単体は 01-network の `google_compute_*` と同じノリ（`google_storage_bucket` 1個）。
   Cloud Run Job 単体は 05-cloudrun-job を参照。なのでここでは扱わない。

## 使い方

各ディレクトリで独立して:

```bash
cd workflows-minimal   # など
terraform init && terraform apply
# README の手順で動作確認
terraform destroy
```

すべて `your-project-id` / `asia-northeast1`。07 本体とは名前が衝突しないようにしてある。

## 学びの順番（おすすめ）

1. `workflows-minimal` … まず Workflows 単体（イベント無しで手動実行）で YAML に慣れる
2. `pubsub-minimal` … メッセージングの基本（Eventarc の裏で動く土台）
3. `eventarc-minimal` … 1 と 2 を「イベントで自動起動」に繋ぐ最小形
4. → そのうえで 07-workflow 本体（GCS と Cloud Run Job も足した統合形）を読む
