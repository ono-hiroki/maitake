# 01-network — VPC / Subnet / Firewall

GCP ネットワークの最小構成を学ぶ最初のステップ。

## 学ぶこと

- **VPC**: GCP では VPC は **グローバル** リソース（AWS はリージョン単位なので注意）
- **Subnet**: サブネットが **リージョン** に紐づく。リソースはここに配置される
- **カスタムモード VPC**: `auto_create_subnetworks = false` でサブネットを明示管理
- **Firewall**: VPC 単位で設定し、`source_ranges` と `priority` で制御
- **Private Google Access**: 外部 IP なしで Google API にアクセスする仕組み
- **API の有効化を Terraform 管理**: `google_project_service` で `compute.googleapis.com` を有効化（`disable_on_destroy = false`）

## 作成されるリソース

| リソース | 名前（例） | 説明 |
|---------|-----------|------|
| VPC | `sbx-demo` | カスタムモード VPC |
| Subnet | `sbx-demo-subnet` | `10.0.0.0/24` @ asia-northeast1 |
| Firewall | `sbx-demo-allow-internal` | 内部 5432/icmp を許可 |

## 実行手順

```bash
# 必要な API（compute.googleapis.com）は Terraform 側で有効化するので gcloud 不要

terraform init
terraform plan
terraform apply

# 確認
gcloud compute networks list --project=your-project-id
gcloud compute networks subnets list --project=your-project-id

# 片付け（課金回避のため学習後は必ず）
terraform destroy
```

## 実運用構成との違い

- 実運用では VPC とサブネットを別管理にすることもある。
  ここでは学習のため VPC・サブネット・Firewall を1ファイルに集約。
- state はローカル（実運用構成は GCS バックエンド）。
