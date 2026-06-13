# 04-cloudsql — Cloud SQL / VPC Peering / Secret Manager

処理結果を保存するリレーショナルDB（PostgreSQL）。
**このモジュールは単体で完結する**（VPC も自分で作るので 01-network には依存しない）。

## 前提

- なし（VPC を含め必要なものは全てこのモジュールで作成する）
- 01-network と同時に存在できるよう、VPC 名は `sbx-demo-sql`（01 は `sbx-demo`）

## 学ぶこと

- **Private Service Access（VPC Peering）**: Cloud SQL に内部IPで繋ぐ仕組み
  1. VPC を作成（PSA はサブネット不要。VPC と予約IP範囲だけでよい）
  2. `google_compute_global_address`（VPC_PEERING）で内部IP範囲を予約
  3. `google_service_networking_connection` で Google サービスVPCとピアリング
  4. Cloud SQL を `private_network` 指定で内部IPのみで起動（外部IPなし）
- **Cloud SQL**: インスタンス → データベース（論理DB）→ ユーザー の階層
- **Secret Manager**: Secret（入れ物）→ SecretVersion（値）。パスワードをコードに直書きしない
- **秘密を tfstate に残さない設計（実運用構成方式）**:
  - DB ユーザーの password は初回用ダミー + `lifecycle.ignore_changes = [password]`
  - Secret は「入れ物」だけ TF で作り、値（SecretVersion）は apply 後に gcloud で手動投入
  - → 本物のパスワードは一度も Terraform / tfstate を通らない
  - ※ Terraform を通った秘密はリソース種別を問わず tfstate に平文で入る、が大原則

## 作成されるリソース

| リソース | 名前 | 説明 |
|---------|------|------|
| API | compute / sqladmin / servicenetworking / secretmanager | 4つ有効化 |
| VPC | `sbx-demo-sql` | このモジュール専用（サブネットなし） |
| Global Address | `sbx-demo-sql-range` | ピアリング用に予約した内部IP範囲 |
| Service Networking 接続 | (VPC peering) | 自VPC ↔ Google サービスVPC |
| Cloud SQL | `sbx-demo` | POSTGRES_15, db-f1-micro, ZONAL, 内部IPのみ |
| Database | `demo` | 論理DB |
| User | `demo_app` | 初回はダミーpw + ignore_changes |
| Secret（入れ物のみ） | `sbx-demo-db-password` | 値は手動投入（TF では作らない） |

## 実行手順

```bash
terraform init
terraform plan
terraform apply   # ⚠️ Cloud SQL 作成は 10〜15分かかる

# 確認
gcloud sql instances list --project=your-project-id
gcloud sql instances describe sbx-demo --project=your-project-id \
  --format="value(ipAddresses[].ipAddress)"   # 内部IPのみ

# --- 本物のパスワードを TF の外で投入する（実運用構成方式） ---
PW=$(openssl rand -base64 24)
# 1) Cloud SQL ユーザーのパスワードを本物に変更（ダミーから上書き。ignore_changes で TF は戻さない）
gcloud sql users set-password demo_app \
  --instance=sbx-demo --password="$PW" --project=your-project-id
# 2) Secret Manager に値（SecretVersion）を投入
printf '%s' "$PW" | gcloud secrets versions add sbx-demo-db-password \
  --data-file=- --project=your-project-id
# 3) 取り出して確認
gcloud secrets versions access latest \
  --secret=sbx-demo-db-password --project=your-project-id

# 片付け（⚠️ コスト発生するので学習後は必ず）
terraform destroy
```

> 💡 内部IPのみなので、手元から直接 psql 接続はできない（VPC内のVMや Cloud SQL Auth Proxy 経由が必要）。
> ここでは「内部IPで起動し、Secret の入れ物ができ、値は TF 外で投入する」流れを確認できれば十分。
>
> 🔒 apply 後の tfstate を見ると、`google_sql_user` の password は**ダミー値のまま**で本物は入っていない。
> これが「秘密を tfstate に通さない」設計の確認ポイント。

## コスト注意

Cloud SQL は**起動している間ずっと課金**される（db-f1-micro でも月数ドル）。
他のモジュールと違い無料ではないので、学習後は `terraform destroy` を忘れずに。

## 実運用構成との違い

- 実運用構成は HA（REGIONAL）・バックアップ・PITR・IAM認証・query insights・maintenance window 等をフル設定。
  ここでは ZONAL・バックアップ無効・db-f1-micro でコスト最小化＆要点に集中。
- 実運用構成は VPC を変数（network_id）で受け取る child モジュール（network モジュールが作った VPC を使う）。
  ここでは各モジュール独立方針のため、VPC もこのモジュール内で自作する。
- Secret の扱いは実運用構成と同じ（入れ物のみ TF 作成、値は手動投入、user は ダミーpw + ignore_changes）。
  → 本物のパスワードを tfstate に残さないため。
