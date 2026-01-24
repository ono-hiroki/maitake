# Argo CD と Kustomize リモートベースの連携

Argo CD は Kustomize をネイティブサポートしており、リモート base を参照する overlay もそのままデプロイできます。このチュートリアルでは、前回作成した Kustomize リモートベースの overlay を Argo CD でデプロイする方法を解説します。

---

## 前提条件

- Docker がインストールされていること
- kind がインストールされていること
- k がインストールされていること
- `12-kustomize-remote-base` の内容を理解していること

---

## ディレクトリ構成

```
14-argocd-kustomize/
├── README.md
└── applications/
    ├── dev-app.yaml       # dev 環境用 Application
    └── prod-app.yaml      # prod 環境用 Application
```

---

## Argo CD の仕組み

### Kustomize との連携フロー

```
1. Argo CD が Git リポジトリから overlay を取得
           ↓
2. overlay 内の kustomization.yaml を検出
           ↓
3. resources に指定されたリモート base を取得
           ↓
4. kustomize build を実行（base + overlay をマージ）
           ↓
5. 生成されたマニフェストをクラスタにデプロイ
```

Argo CD は `kustomization.yaml` を検出すると自動的に Kustomize モードで動作します。

---

## ハンズオン

### Step 1: kind でクラスターを作成

```bash
# クラスターを作成
kind create cluster --name argocd-demo

# コンテキストを確認
k cluster-info --context kind-argocd-demo
```

出力例:
```
Kubernetes control plane is running at https://127.0.0.1:xxxxx
CoreDNS is running at https://127.0.0.1:xxxxx/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

### Step 2: Argo CD のインストール

```bash
# namespace 作成
k create namespace argocd

# Argo CD インストール
k apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# インストール完了を待機
k wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### Step 3: Argo CD CLI のインストール（オプション）

```bash
# macOS
brew install argocd

# または直接ダウンロード
# https://argo-cd.readthedocs.io/en/stable/cli_installation/
```

### Step 4: Argo CD にログイン

```bash
# 初期ユーザー名: admin
# 初期パスワードを取得
k -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# ポートフォワード
k port-forward svc/argocd-server -n argocd 8080:443

# CLI でログイン（別ターミナルで）
argocd login localhost:8080 --username admin --password <初期パスワード> --insecure
```

ブラウザで https://localhost:8080 にアクセスしても OK です。

### Step 5: Application の確認

```yaml
# applications/dev-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hello-dev
  namespace: argocd
spec:
  project: default
  source:
    # このリポジトリの overlay を参照
    repoURL: https://github.com/ono-hiroki/maitake.git
    targetRevision: main
    path: kubernetes/12-kustomize-remote-base/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: hello-dev
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

ポイント:
- `path`: overlay のパスを指定（kustomization.yaml があるディレクトリ）
- `syncOptions: CreateNamespace=true`: namespace を自動作成
- Argo CD が自動で `kustomize build` を実行

### Step 6: Application をデプロイ

```bash
# dev 環境
k apply -f applications/dev-app.yaml

# prod 環境
k apply -f applications/prod-app.yaml
```

Application を作成しただけでは、まだクラスタにリソースはデプロイされません（`OutOfSync` 状態）。
手動で同期を実行します。

```bash
# 手動で同期
argocd app sync hello-dev
argocd app sync hello-prod
```

prod-app.yaml には `syncPolicy.automated` が設定されているため、自動で同期されます。
dev は手動同期のみなので、変更があるたびに `argocd app sync` を実行する必要があります。

### Step 7: 同期状態を確認

```bash
# CLI で確認
argocd app list

# 詳細を確認
argocd app get hello-dev
```

出力例:
```
Name:               argocd/hello-dev
Project:            default
Server:             https://kubernetes.default.svc
Namespace:          hello-dev
URL:                https://localhost:8080/applications/hello-dev
Source:
  Repo:             https://github.com/ono-hiroki/maitake.git
  Path:             kubernetes/12-kustomize-remote-base/overlays/dev
  Target:           main
SyncPolicy:         <none>
Status:             Synced
Health:             Healthy
```

確認ポイント:
- **Status: Synced**: Git の状態とクラスタの状態が一致している
- **Health: Healthy**: デプロイされたリソースが正常に動作している

| Status | 意味 |
|--------|------|
| Synced | Git とクラスタが一致 |
| OutOfSync | Git とクラスタに差分あり（要同期） |

| Health | 意味 |
|--------|------|
| Healthy | すべてのリソースが正常 |
| Progressing | デプロイ中 |
| Degraded | 一部のリソースに問題あり |
| Missing | リソースがクラスタに存在しない |

### Step 8: リモート base との差分を確認

Argo CD がビルドした結果と、ローカルの kustomize build 結果を比較できます。

```bash
# Argo CD がビルドしたマニフェストを表示
argocd app manifests hello-dev

# ローカルの kustomize build 結果と比較
diff -u \
  <(argocd app manifests hello-dev) \
  <(k kustomize ../12-kustomize-remote-base/overlays/dev)
```

出力例:
```diff
--- /dev/fd/11
+++ /dev/fd/12
@@ -1,13 +1,9 @@
----
 apiVersion: v1
 kind: Service
 metadata:
-  annotations:
-    argocd.argoproj.io/tracking-id: hello-dev:/Service:hello-dev/dev-hello-service
   labels:
     env: development
   name: dev-hello-service
-  namespace: hello-dev
 ...
```

差分のポイント:
- **tracking-id**: Argo CD がリソースを追跡するために自動付与する annotation
- **namespace**: Application の `destination.namespace` で指定した値が追加される
- **---**: YAML ドキュメント区切り

これらは Argo CD が自動的に追加するメタデータなので、差分があっても問題ありません。
アプリケーションのコア部分（image, replicas, labels など）が一致していれば OK です。

### Step 9: クリーンアップ

```bash
# Application を削除（リソースも削除される）
argocd app delete hello-dev --cascade
argocd app delete hello-prod --cascade

# または
k delete -f applications/

# kind クラスターを削除
kind delete cluster --name argocd-demo
```

---

## dev と prod の違い

| 項目 | dev | prod |
|------|-----|------|
| namespace | hello-dev | hello-prod |
| namePrefix | dev- | prod- |
| replicas | 2 | 5 |
| image tag | nginx:1.25 | nginx:1.26 |
| resources | なし | requests/limits あり |
| 自動同期 | なし | あり |

---

## トラブルシューティング

### リモート base の取得に失敗する

```bash
# Argo CD のログを確認
k logs -n argocd deployment/argocd-repo-server

# キャッシュをクリアして再同期
argocd app get hello-dev --hard-refresh
```

### Private リポジトリを使う場合

```bash
# リポジトリを登録
argocd repo add https://github.com/yourname/private-repo \
  --username <username> \
  --password <token>

# SSH の場合
argocd repo add git@github.com:yourname/private-repo.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```

### 同期が OutOfSync のまま

```bash
# 差分を確認
argocd app diff hello-dev

# 強制同期
argocd app sync hello-dev --force
```

---

## まとめ

| 項目 | 説明 |
|------|------|
| **Kustomize 検出** | `kustomization.yaml` があれば自動で Kustomize モード |
| **リモート base** | overlay 内の resources で指定されたリモート base も自動取得 |
| **自動同期** | `syncPolicy.automated` で Git の変更を自動反映 |
| **namespace 作成** | `CreateNamespace=true` で自動作成 |

---

## 参考リンク

- [Argo CD - Kustomize](https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/)
- [Argo CD - Application Specification](https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/)
- [Kustomize - Remote Targets](https://k.docs.kubernetes.io/references/kustomize/kustomization/resource/)
