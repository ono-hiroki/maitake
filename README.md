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
| 14 | [Argo CD と Kustomize リモートベースの連携](./kubernetes/14-argocd-kustomize/) | GitOps によるデプロイ自動化 |

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
    └── 14-argocd-kustomize/       # Argo CD + Kustomize
```

## 参考資料

- [Kubernetes 公式ドキュメント](https://kubernetes.io/docs/)
- [kubectl チートシート](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Helm ドキュメント](https://helm.sh/docs/)
- [Kustomize ドキュメント](https://kustomize.io/)
- [Argo CD ドキュメント](https://argo-cd.readthedocs.io/)
