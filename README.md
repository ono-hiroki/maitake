# maitake

インフラ・バックエンドの学習や検証をまとめたリポジトリです。

## 概要

このリポジトリでは、Kubernetes を中心としたコンテナオーケストレーションの基礎から実践的なトピックまでを、ハンズオン形式で学習できます。各チュートリアルは独立しており、順番に進めることで体系的に理解を深められます。

## 前提条件

### 必要なツール

| ツール | 用途 |
|--------|------|
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | コンテナランタイム + Kubernetes クラスター |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Kubernetes CLI |

### 環境セットアップ

1. **Docker Desktop をインストール**
   - [公式サイト](https://www.docker.com/products/docker-desktop/)からダウンロード

2. **Kubernetes を有効化**
   - Docker Desktop の Settings > Kubernetes > Enable Kubernetes にチェック

3. **クラスターの動作確認**
   ```bash
   kubectl cluster-info
   ```

4. **kubectl エイリアス設定（推奨）**
   ```bash
   # ~/.zshrc に追加
   alias k='kubectl'
   source <(kubectl completion zsh)
   compdef k=kubectl
   ```

## チュートリアル一覧

### Kubernetes 基礎

| # | タイトル | 学習内容 |
|---|----------|----------|
| 02 | [はじめてのPodをnginxで動かす](./kubernetes/02-pod/) | Pod の起動・確認・削除、Namespace の基本操作 |
| 03 | [manifestファイルでPodを定義する](./kubernetes/03-manifest/) | YAML による宣言的なリソース管理 |
| 04 | [ReplicaSetでPodを管理する](./kubernetes/04-replicaset/) | Pod のレプリケーションと自己修復 |
| 05 | [ServiceでPodにアクセスする](./kubernetes/05-service/) | ClusterIP、NodePort、LoadBalancer |
| 06 | [Ingressで複数Serviceにパスベースルーティング](./kubernetes/06-ingress/) | L7 ロードバランシングとルーティング |
| 07 | [Deploymentでアプリケーションを更新する](./kubernetes/07-deployment/) | ローリングアップデートとロールバック |
| 08 | [HPAでPodを自動スケーリングする](./kubernetes/08-hpa/) | 負荷に応じた水平スケーリング |

### 設定管理

| # | タイトル | 学習内容 |
|---|----------|----------|
| 09 | [ConfigMapで設定を管理する](./kubernetes/09-configmap/) | 環境変数・設定ファイルの外部化 |
| 10 | [Secretで機密情報を管理する](./kubernetes/10-secret/) | パスワード・APIキーの安全な管理 |

### パッケージ管理・GitOps

| # | タイトル | 学習内容 |
|---|----------|----------|
| 11 | [Helmでパッケージ管理する](./kubernetes/11-helm/) | Chart を使ったアプリケーションのデプロイ |
| 12 | [Kustomizeで環境別マニフェストを管理する](./kubernetes/12-kustomize/) | Base と Overlay による環境差分管理 |
| 12+ | [Kustomizeでリモートbaseを使う](./kubernetes/12-kustomize-remote-base/) | Git リポジトリからの base 参照 |
| 13 | [RBACでアクセス制御する](./kubernetes/13-rbac/) | Role、RoleBinding によるアクセス権限管理 |
| 14 | [Argo CD 入門](./kubernetes/14-argocd-introduction/) | GitOps の概念、Argo CD のアーキテクチャと主要概念、ハンズオン |
| 14+ | [Argo CD と Kustomize リモートベースの連携](./kubernetes/14-argocd-kustomize/) | GitOps によるデプロイ自動化 |

### サービスメッシュ

| # | タイトル | 学習内容 |
|---|----------|----------|
| 15 | [Istio でサービスメッシュを構築する](./kubernetes/15-istio/) | サイドカー注入、オブザーバビリティ、トラフィック管理、サーキットブレーカー、Gateway |

## AWS ネットワーク

### ネットワーク基礎

| # | タイトル | 学習内容 |
|---|----------|----------|
| 01 | [VPCをTerraformで構築してWebサーバーを公開する](./aws-network/01-vpc-basics/) | VPC、サブネット、IGW、ルートテーブル、セキュリティグループ、パブリック/プライベートサブネットの違い |
| 02 | [ALBで複数のEC2にリクエストを負荷分散する](./aws-network/02-alb/) | ALB、リスナー、ターゲットグループ、ヘルスチェック、セキュリティグループの分離 |

### 前提条件

| ツール | 用途 |
|--------|------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | IaC |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | リソースの確認 |

## Azure ネットワーク

### ネットワーク基礎

| # | タイトル | 学習内容 |
|---|----------|----------|
| 01 | [VNetをTerraformで構築してWebサーバーを公開する](./azure-network/) | VNet、サブネット、NSG、Public IP、NIC、Linux VM、cloud-init |

### 前提条件

| ツール | 用途 |
|--------|------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | IaC |
| [Azure CLI](https://docs.microsoft.com/ja-jp/cli/azure/install-azure-cli) | リソースの確認 |

## GCP サービス Terraform ハンズオン

GCP の主要サービスを、それぞれ独立した最小の Terraform root として単体で構築して学ぶサンプル集。
各サンプルは自己完結していて、好きなものから単体で `apply` できる。

| タイトル | 学習内容 |
|----------|----------|
| [VPC / Subnet / Firewall](./gcp-terraform-handson/vpc-network/) | カスタムモード VPC、サブネット、ファイアウォール |
| [BigQuery](./gcp-terraform-handson/bigquery/) | サーバレス DWH、データセット/テーブル/スキーマ |
| [Firestore](./gcp-terraform-handson/firestore/) | NoSQL ドキュメント DB |
| [Cloud SQL](./gcp-terraform-handson/cloudsql/) | Private Service Access、秘密を tfstate に残さない設計 |
| [Cloud Run Job](./gcp-terraform-handson/cloudrun-job/) | バッチ実行、Artifact Registry、Service Account |
| [Cloud Run Service / IAP](./gcp-terraform-handson/cloudrun-service-iap/) | 常駐サービス、IAP 認証 |
| [Workflows](./gcp-terraform-handson/workflows/) | YAML オーケストレーション（単体） |
| [Pub/Sub](./gcp-terraform-handson/pubsub/) | topic / subscription |
| [Eventarc](./gcp-terraform-handson/eventarc/) | イベント → 自動起動（単体） |
| [Workload Identity Federation](./gcp-terraform-handson/workload-identity-federation/) | GitHub Actions の鍵レス認証 |

### 前提条件

| ツール | 用途 |
|--------|------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | IaC |
| [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) | 認証・リソースの確認 |

## 使い方

1. 各チュートリアルのディレクトリに移動
2. README.md の手順に従って実践
3. クリーンアップを実施して次のチュートリアルへ

```bash
# 例: Pod チュートリアルを始める
cd kubernetes/02-pod
cat README.md
```

## ディレクトリ構成

```
maitake/
├── aws-network/         # AWS ネットワーク ハンズオン
│   ├── 01-vpc-basics/   # VPC 基礎
│   └── 02-alb/          # ALB 負荷分散
├── azure-network/       # Azure ネットワーク ハンズオン
├── gcp-terraform-handson/    # GCP 各サービスの単体 Terraform サンプル集
└── kubernetes/          # Kubernetes ハンズオン
    ├── 02-pod/          # Pod 基礎
    ├── 03-manifest/     # マニフェストファイル
    ├── 04-replicaset/   # ReplicaSet
    ├── 05-service/      # Service
    ├── 06-ingress/      # Ingress
    ├── 07-deployment/   # Deployment
    ├── 08-hpa/          # HPA
    ├── 09-configmap/    # ConfigMap
    ├── 10-secret/       # Secret
    ├── 11-helm/         # Helm
    ├── 12-kustomize/    # Kustomize
    ├── 12-kustomize-remote-base/  # Kustomize リモートbase
    ├── 13-rbac/         # RBAC
    ├── 14-argocd-introduction/    # Argo CD 入門
    ├── 14-argocd-kustomize/       # Argo CD + Kustomize
    ├── 15-istio/                  # Istio サービスメッシュ
    └── 99-capstone/     # EKS Capstone（別リポジトリへのリンク）
```

## 関連プロジェクト

| リポジトリ | 説明 |
|-----------|------|
| [eks-capstone-base](https://github.com/ono-hiroki/eks-capstone-base) | EKS を使った Kubernetes 学習の集大成プロジェクト。Terraform による EKS クラスタ構築、Kustomize リモートベース、Argo CD による GitOps、Istio サービスメッシュなどを実践 |

## 参考資料

- [Kubernetes 公式ドキュメント](https://kubernetes.io/docs/)
- [kubectl チートシート](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Helm ドキュメント](https://helm.sh/docs/)
- [Kustomize ドキュメント](https://kustomize.io/)
- [Argo CD ドキュメント](https://argo-cd.readthedocs.io/)
