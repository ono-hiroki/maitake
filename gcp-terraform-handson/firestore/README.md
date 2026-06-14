# firestore — Firestore Database

NoSQL ドキュメントDB を学ぶ。demo ではプロンプト等の保存に使用。

## 学ぶこと

- **NoSQL ドキュメントDB**: 階層は Database → Collection → Document（JSON 風）
- **BigQuery との対比**: BQ=分析向け表形式 / Firestore=アプリの可変データ向け
- **FIRESTORE_NATIVE vs DATASTORE_MODE**: 通常は NATIVE を選ぶ
- **named database**: プロジェクト内に複数DBを持てる（`(default)` 以外に名前付き）
- **location_id は不変**: 作成後に変更不可
- **PITR / delete_protection**: 復元・誤削除防止の運用機能

## 作成されるリソース

| リソース | 名前 | 説明 |
|---------|------|------|
| API | `firestore.googleapis.com` | Firestore API 有効化 |
| Database | `sbx-demo` | FIRESTORE_NATIVE @ asia-northeast1 |

## 実行手順

```bash
terraform init
terraform plan
terraform apply

# 確認（データベース一覧）
gcloud firestore databases list --project=your-project-id

# ドキュメントの読み書きは REST API で行う。
# （gcloud firestore に documents サブコマンドは無い: databases/indexes/export 等のみ）
PROJECT=your-project-id; DB=sbx-demo
TOKEN=$(gcloud auth print-access-token)

# 書き込み: documents コレクションに doc-1 を作成
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "https://firestore.googleapis.com/v1/projects/$PROJECT/databases/$DB/documents/documents?documentId=doc-1" \
  -d '{"fields":{"title":{"stringValue":"テスト"},"content":{"stringValue":"本文"}}}' | jq '{name, fields}'

# 読み出し: documents コレクションの一覧
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://firestore.googleapis.com/v1/projects/$PROJECT/databases/$DB/documents/documents" \
  | jq '.documents[] | {name, fields}'

# 片付け（delete_protection DISABLED なので destroy 可）
terraform destroy
```

> Firestore のフィールドは型付きで表現する（`stringValue` / `integerValue` / `timestampValue` 等）。
> コンソール（https://console.cloud.google.com/firestore/databases/sbx-demo/data?project=your-project-id ）
> なら GUI でコレクション/ドキュメントを直感的に作成・閲覧できる。
>
> ※ `gcloud firestore documents create` は存在しない。`gcloud firestore --help` のサブコマンドは
> databases / backups / export / import / indexes / fields など。ドキュメント CRUD は REST API か各言語SDK を使う。

## 実運用構成との違い

- 実運用構成は `delete_protection_state = "DELETE_PROTECTION_ENABLED"`（誤削除防止）。
  学習用は `DISABLED` にして `terraform destroy` できるようにしている。
- 実運用構成の name は `${env}-${project_name}-prompts`。ここでは `${env}-${db_name}` に簡略化。
