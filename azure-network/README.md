# Azure ネットワーク基礎

TerraformでAzure上にVNet、サブネット、NSG、VMを構築し、nginxでWebサーバーを公開します。

## 構成図

```
┌─────────────────────────────────────────────────────────────┐
│ Resource Group: network-basic-rg                            │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ VNet: 10.0.0.0/16                                     │  │
│  │                                                       │  │
│  │  ┌─────────────────────┐  ┌─────────────────────┐    │  │
│  │  │ Public Subnet       │  │ Private Subnet      │    │  │
│  │  │ 10.0.1.0/24         │  │ 10.0.2.0/24         │    │  │
│  │  │                     │  │                     │    │  │
│  │  │  ┌─────────────┐    │  │                     │    │  │
│  │  │  │ VM (nginx)  │    │  │                     │    │  │
│  │  │  │ + Public IP │    │  │                     │    │  │
│  │  │  └─────────────┘    │  │                     │    │  │
│  │  │                     │  │                     │    │  │
│  │  │  [NSG: SSH/HTTP/S]  │  │  [NSG: VNet only]   │    │  │
│  │  └─────────────────────┘  └─────────────────────┘    │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                    │
                    ▼
              Internet (HTTP/SSH)
```

## 前提条件

- [Terraform](https://developer.hashicorp.com/terraform/install)
- [Azure CLI](https://docs.microsoft.com/ja-jp/cli/azure/install-azure-cli)
- Azureサブスクリプション

## セットアップ

```bash
# Azure にログイン
az login

# リポジトリをクローン
git clone https://github.com/ono-hiroki/maitake.git
cd maitake/azure-network

# Terraform 初期化
terraform init

# プラン確認
terraform plan

# 適用
terraform apply
```

## 動作確認

```bash
# Webサーバーにアクセス
curl http://$(terraform output -raw vm_public_ip)

# SSH接続
ssh azureuser@$(terraform output -raw vm_public_ip)
```

## クリーンアップ

```bash
terraform destroy
```

## ハマりポイント

### 1. VMサイズ（SKU）が利用できない

```
SkuNotAvailable: Standard_B1s is currently not available in location 'japaneast'
```

**原因**: 日本リージョンでBシリーズ等のキャパシティ不足が頻発

**解決策**:
- `Standard_D2s_v3` など別のサイズを使用
- 利用可能なSKUを事前に確認:
  ```bash
  az vm list-skus --location japanwest --size Standard_D --output table
  ```

### 2. Gen1/Gen2イメージの互換性

```
BadRequest: The selected VM size 'Standard_A1_v2' cannot boot Hypervisor Generation '2'
```

**原因**: 古いVMサイズはGen2イメージ非対応

**解決策**:
- Gen2対応のVMサイズを使う（D2s_v3など）
- または `sku = "22_04-lts"`（Gen1）に変更

### 3. Terraformプロバイダーのバグ

```
Provider produced inconsistent result after apply
```

**原因**: Azure RMプロバイダーのバグでstateが破損

**解決策**:
- prefixを変更して新しいリソースグループで再作成
- または `terraform import` で修復

## ファイル構成

| ファイル | 内容 |
|---------|------|
| main.tf | プロバイダー設定、リソースグループ |
| variables.tf | 変数定義（prefix, location, tags） |
| network.tf | VNet、サブネット、NSG |
| vm.tf | Public IP、NIC、Linux VM |
| outputs.tf | 出力（IP、SSH接続コマンド） |

## 参考

- [Azure Provider ドキュメント](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure VM サイズ一覧](https://docs.microsoft.com/ja-jp/azure/virtual-machines/sizes)
