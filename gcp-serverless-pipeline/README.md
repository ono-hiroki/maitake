# gcp-serverless-pipeline — GCP のサーバーレス・イベント駆動パイプラインを1モジュールずつ学ぶ

「ファイルを Cloud Storage に置くと、自動で処理が走って DB に保存される」——
GCP のサーバーレス・イベント駆動な構成を題材に、**各要素を独立した最小の Terraform root として
1つずつ作りながら** GCP を学ぶハンズオン集です。GCP 初学者が、実在のシステム構成レベルの
知識を要素分解して身につけることを狙っています。

## 題材アーキテクチャ（全体像）

```
                ┌─────────────┐
  ファイル投入 → │Cloud Storage│
                └──────┬──────┘
                       │ オブジェクト作成イベント
                       ▼
                  ┌─────────┐      ┌───────────┐      ┌──────────────┐
                  │ Eventarc│ ───► │ Workflows │ ───► │ Cloud Run Job│
                  └─────────┘      └───────────┘      └──────┬───────┘
                                                             ├──► Cloud SQL
                                                             └──► BigQuery

  可視化デモ: Cloud Run Service + IAP認証
  CI/CD:    Workload Identity Federation + GitHub Actions
```

## 学習ロードマップ（基礎 → 応用）

| #  | ディレクトリ      | 学ぶ GCP サービス・概念 |
|----|------------------|------------------------|
| 01 | `01-network`     | VPC / Subnet / Firewall |
| 02 | `02-bigquery`    | BigQuery Dataset / Table（データウェアハウス） |
| 03 | `03-firestore`   | Firestore（NoSQL ドキュメント DB） |
| 04 | `04-cloudsql`    | Cloud SQL / Secret Manager / Private Service Access |
| 05 | `05-cloudrun-job` | Cloud Run Job / Artifact Registry / Service Account |
| 06 | `06-cloudrun-service` | Cloud Run Service / IAP 認証 |
| 07 | `07-workflow`    | Eventarc / Workflows（イベント駆動） |
| 08 | `08-cicd`        | Workload Identity Federation（鍵レス認証） |

データ保存（02-04）→ コンピュート（05-06）→ イベント連携（07）→ CI/CD（08）の順。
依存の少ない方から積み上げる構成です。`07-workflow/components/` には Workflows / Pub/Sub /
Eventarc を**単体**で試す最小モジュールも置いています。

## 前提条件

| ツール | 用途 |
|--------|------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | IaC |
| [Google Cloud CLI (`gcloud`)](https://cloud.google.com/sdk/docs/install) | 認証・リソース確認 |

```bash
gcloud auth login
gcloud auth application-default login   # Terraform 用
```

## 共通の進め方

各ディレクトリは独立した Terraform root（state はローカル）。

```bash
cd 01-network
cp terraform.tfvars.example terraform.tfvars   # project_id を自分の値に編集
terraform init
terraform plan
terraform apply
# 動作確認したら...
terraform destroy    # 課金を避けるため学習後は削除
```

- **リージョン**: `asia-northeast1`（東京）
- `terraform.tfvars` は各自で作成（`*.tfvars` は Git 管理外）。`terraform.tfvars.example` を参照。

### 設計メモ

- **API 有効化も Terraform 管理**: 各モジュールが必要な API を `google_project_service` で有効化
  （`disable_on_destroy = false`）。どのサービスがどの API を要るかが明確になる。
- **学習用の簡略化**: 実運用では env 分離・GCS リモート state・再利用可能な child モジュール構成に
  するのが一般的。本ハンズオンは理解優先で、単一・ローカル state・root 直書き・コメント厚めにしている。
- 各ディレクトリの README に「学ぶこと」「実行手順」「ハマりどころ」を記載。

## 横断的な学び（GCP のクセ）

モジュールを跨いで繰り返し出てくる、GCP 全般で効く知識:

- **IAM は結果整合（伝播待ち）**: 権限付与直後は反映前で 403/400 になることがある。
  Terraform では `time_sleep` で待機を挟む / 手動なら数分待って再実行（06 IAP・07 Eventarc で遭遇）。
- **`deletion_protection` がデフォルト true** のリソースが多い（Cloud SQL / Cloud Run / Workflows /
  Firestore / BigQuery table）。学習用は false、本番は true。
- **`ignore_changes`** でイメージ・環境変数・パスワードを TF 管理外にし、「インフラの骨組みは TF /
  中身は CI・手動運用」と役割分担する。
- **秘密を tfstate に持ち込まない**（04 cloudsql）。Terraform を通った秘密は tfstate に平文で残るため、
  ダミー値 + `ignore_changes` + 値は手動投入、という設計にする。
- **`terraform graph | dot -Tpng`** で依存を可視化すると、モジュールの複雑度が edge 数で見える。
