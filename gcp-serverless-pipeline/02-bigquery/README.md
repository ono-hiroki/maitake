# 02-bigquery — BigQuery Dataset / Table

処理データの保存先となるデータウェアハウスを学ぶ。

## 学ぶこと

- **サーバレス DWH**: インスタンス管理不要。保存量とクエリのスキャン量で課金
- **階層**: Project → Dataset（location を持つ入れ物）→ Table（スキーマを持つ）
- **dataset_id の制約**: 英数字と `_` のみ。ハイフン不可 → `replace(..., "-", "_")`
- **location は不変**: 作成後に変更できない（asia-northeast1 等）
- **schema 定義**: JSON で `name` / `type` / `mode`（NULLABLE / REQUIRED / REPEATED）
- **delete_contents_on_destroy / deletion_protection**: 誤削除防止の仕組み

## 作成されるリソース

| リソース | 名前 | 説明 |
|---------|------|------|
| API | `bigquery.googleapis.com` | BigQuery API 有効化 |
| Dataset | `sbx_demo` | location: asia-northeast1 |
| Table | `documents` | document_id / title / content / created_at |

## 実行手順

```bash
terraform init
terraform plan
terraform apply

# 確認
bq ls --project_id=your-project-id                       # データセット一覧
bq show --schema your-project-id:sbx_demo.documents  # テーブルのスキーマ
# サンプルデータを入れてみる
bq query --project_id=your-project-id --use_legacy_sql=false \
  'INSERT INTO `sbx_demo.documents` (document_id, title, created_at) VALUES ("doc-1", "テスト", CURRENT_TIMESTAMP())'
bq query --project_id=your-project-id --use_legacy_sql=false \
  'SELECT * FROM `sbx_demo.documents`'

# 片付け（delete_contents_on_destroy=true なのでテーブルごと消える）
terraform destroy
```

## 実運用構成との違い

- 実運用構成は Dataset のみ。ここでは学習のためサンプル Table（スキーマ付き）も作成。
- 実運用構成は `delete_contents_on_destroy = false`（誤削除防止）。学習用は `true` で destroy を簡単に。
