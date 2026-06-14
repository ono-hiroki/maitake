# gcp-terraform-handson — GCP の各サービスを Terraform で単体最小構成で触る

GCP の主要サービスを、**それぞれ独立した最小の Terraform root** として 1 つずつ構築して学ぶサンプル集。
各ディレクトリは自己完結していて、好きなものから単体で `apply` できる（順序や依存関係はない）。

## サンプル一覧

| ディレクトリ | 学ぶ GCP サービス・概念 |
|------------------|------------------------|
| [`vpc-network`](./vpc-network/) | VPC / Subnet / Firewall（カスタムモード VPC） |
| [`bigquery`](./bigquery/) | BigQuery Dataset / Table（サーバレス DWH） |
| [`firestore`](./firestore/) | Firestore（NoSQL ドキュメント DB） |
| [`cloudsql`](./cloudsql/) | Cloud SQL / Private Service Access / Secret Manager |
| [`cloudrun-job`](./cloudrun-job/) | Cloud Run Job（バッチ実行）/ Artifact Registry / Service Account |
| [`cloudrun-service-iap`](./cloudrun-service-iap/) | Cloud Run Service（常駐 HTTP）/ IAP 認証 |
| [`workflows`](./workflows/) | Workflows（YAML オーケストレーション、単体） |
| [`pubsub`](./pubsub/) | Pub/Sub（topic / subscription、publish & pull） |
| [`eventarc`](./eventarc/) | Eventarc（イベント → 自動起動、単体） |
| [`workload-identity-federation`](./workload-identity-federation/) | Workload Identity Federation（GitHub Actions の鍵レス認証） |

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
cd vpc-network                                  # 触りたいサンプルへ
cp terraform.tfvars.example terraform.tfvars    # project_id を自分の値に編集
terraform init
terraform plan
terraform apply
# 確認したら...
terraform destroy
```

- **リージョン**: `asia-northeast1`（東京）
- `terraform.tfvars` は各自で作成（`*.tfvars` は Git 管理外）。`terraform.tfvars.example` を参照。

### 設計メモ

- **API 有効化も Terraform 管理**: 各サンプルが必要な API を `google_project_service` で有効化
  （`disable_on_destroy = false`）。どのサービスがどの API を要るかが明確になる。
- **学習用の簡略化**: state はローカル、root に直書き、コメント厚め。本番では env 分離・GCS リモート
  state・再利用可能な child モジュール構成にするのが一般的。
- 各ディレクトリの README に「学ぶこと」「実行手順」「ハマりどころ」を記載。

## 横断的な学び（GCP のクセ）

サンプルを跨いで共通して現れる、GCP 全般で効く挙動:

- **IAM は結果整合（伝播待ち）**: 権限付与の直後は反映前で 403/400 になることがある。
  Terraform では `time_sleep` で待機を挟む / 手動なら数分待って再実行（IAP・Eventarc・Workflows で遭遇）。
- **`deletion_protection` がデフォルト true** のリソースが多い（Cloud SQL / Cloud Run / Workflows /
  Firestore / BigQuery table）。学習用は false、本番は true。
- **`ignore_changes`** でイメージ・環境変数・パスワードを TF 管理外にし、「インフラの骨組みは TF /
  中身は CI・手動運用」と役割分担する。
- **秘密を tfstate に持ち込まない**（`cloudsql` 参照）。Terraform を通った秘密は tfstate に平文で残るため、
  ダミー値 + `ignore_changes` + 値は手動投入、という構成にする。
- **`terraform graph | dot -Tpng`** で依存を可視化すると、各サンプルの複雑度が edge 数で見える。

## サービスの組み合わせメモ

各サンプルは単体だが、組み合わせ方は GCP 共通の知識として有用:

- **Eventarc の宛先**は HTTP を受けるもの（Cloud Run Service / Workflows / GKE）。
  Cloud Run **Job** は HTTP を受けないため、Eventarc から直接は起動できず、Workflows 等で Jobs API を呼ぶ。
- **GCS をイベント源**にする Eventarc は内部で Pub/Sub を使う（GCS サービスエージェントに `pubsub.publisher` が必要）。
