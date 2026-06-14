# workflows-minimal — Workflows 単体の最小構成

イベントも Cloud Run Job も無し。**手動実行する超小さい Workflow** だけ。
Workflows の「YAML で手順を書く → 実行する」感覚を掴むのが目的。

## 作るもの

- `google_workflows_workflow`（`workflow.yaml`：引数を受けてログ出力＆挨拶を返す）
- 実行用 SA（`logging.logWriter` のみ）

## 試す

```bash
terraform init && terraform apply

# 実行（引数 JSON を渡す）
gcloud workflows run min-workflows --location=asia-northeast1 --project=your-project-id \
  --data='{"name":"hono"}'
# → result に "Hello, hono!" が返る

# 実行履歴
gcloud workflows executions list min-workflows --location=asia-northeast1 --project=your-project-id --limit=3

terraform destroy
```

> ⚠️ apply 直後の初回実行は `403 logging.logEntries.create denied` で失敗することがある。
> これは SA への `logging.logWriter` 付与の **IAM 伝播待ち**（設定は正しい）。
> 1〜2分待って再実行すれば `SUCCEEDED` になる。GCP の IAM は結果整合なので「設定したのに
> 権限エラー」はまず伝播を疑う、の好例（eventarc サンプルの time_sleep と同じ仕組み）。

## ポイント

- `params: [input]` が実行時の JSON を受け取る。`${...}` は **Workflows の実行時式**
  （Terraform 側は `file()` で読むだけなので展開されない。`templatefile()` だと `$${...}` 必要）。
- `call: sys.log` で Cloud Logging に出力。`return:` でワークフローの戻り値を返す。
- ここに「HTTP 呼び出し」「条件分岐」「並列」などを足していくと本格的なオーケストレーションになる。
