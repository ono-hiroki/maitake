# Kustomizeでリモートbaseを使う

Kustomize の `resources` にはローカルパスだけでなく、**リモートの Git リポジトリ URL** を指定できます。この機能を使うと、公開リポジトリの base を参照しながら、ローカルやプライベートリポジトリで overlay を管理できます。

---

## 基本構文

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  # ローカルパス
  - ./local-dir

  # リモート Git リポジトリ
  - https://github.com/user/repo//path/to/dir?ref=main
```

### URL の構造

```
https://github.com/user/repo//path/to/dir?ref=main
                            ^^           ^^^^^^^^^
                            ||           |
                            ||           └─ ブランチ、タグ、コミットハッシュ
                            |└─ リポジトリ内のパス
                            └─ 区切り（ダブルスラッシュ）
```

| 部分 | 説明 | 例 |
|-----|------|-----|
| `https://github.com/user/repo` | リポジトリ URL | `https://github.com/kubernetes-sigs/kustomize` |
| `//` | 区切り（必須） | - |
| `path/to/dir` | リポジトリ内のパス | `examples/helloWorld` |
| `?ref=` | バージョン指定 | `?ref=main`, `?ref=v1.0.0`, `?ref=abc1234` |

---

## ハンズオン

このリポジトリを使って、リモート base を参照する overlay を試してみましょう。

### ディレクトリ構成

```
12-kustomize-remote-base/
├── README.md
└── overlays/
    ├── dev/
    │   └── kustomization.yaml      # 開発環境用
    └── prod/
        ├── kustomization.yaml      # 本番環境用
        └── patches/
            └── deployment-patch.yaml
```

### Step 1: overlay の確認

```yaml
# overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# リモートの base を参照
resources:
  - https://github.com/ono-hiroki/kustomize-base-example.git/bases/helloworld?ref=main

# ローカルでカスタマイズ
namePrefix: dev-

labels:
  - pairs:
      env: development
    includeSelectors: true

# レプリカ数を変更
replicas:
  - name: hello-app
    count: 2
```

### Step 2: ビルドして確認

```bash
kubectl kustomize overlays/dev
```

出力例:
```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    env: development          # ← 追加されたラベル
  name: dev-hello-service     # ← dev- プレフィックス付き
spec:
  ...
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    env: development          # ← 追加されたラベル
  name: dev-hello-app         # ← dev- プレフィックス付き
spec:
  replicas: 2                 # ← 変更されたレプリカ数
  ...
```

### Step 3: リモート base との差分を確認

リモート base をそのままビルドした結果と、overlay 適用後の差分を確認できます。

```bash
# リモート base と overlay 後の差分を表示
# ※ URL は zsh の ? 展開を防ぐためクォートで囲む
diff -u \
  <(kubectl kustomize 'https://github.com/ono-hiroki/kustomize-base-example.git/bases/helloworld?ref=main') \
  <(kubectl kustomize overlays/dev)
```

出力例:
```diff
--- /dev/fd/11
+++ /dev/fd/12
@@ -2,7 +2,8 @@
 kind: Service
 metadata:
-  name: hello-service
+  labels:
+    env: development
+  name: dev-hello-service
 ...
@@ -11,7 +12,9 @@
 kind: Deployment
 metadata:
-  name: hello-app
+  labels:
+    env: development
+  name: dev-hello-app
 spec:
-  replicas: 3
+  replicas: 2
```

これにより、overlay で何が変更されたかを明確に把握できます。

### Step 4: 環境間の差分を確認

dev と prod の overlay を比較することもできます。

```bash
diff -u \
  <(kubectl kustomize overlays/dev) \
  <(kubectl kustomize overlays/prod)
```

---

## 実用例: prod overlay でパッチを適用

このリポジトリの prod overlay では、Strategic Merge Patch を使ってリソース制限を追加しています。

### prod overlay の構成

```yaml
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# 同じリモート base を参照
resources:
  - https://github.com/ono-hiroki/kustomize-base-example.git/bases/helloworld?ref=main

# 本番環境用のカスタマイズ
namePrefix: prod-

labels:
  - pairs:
      env: production
    includeSelectors: true

# レプリカ数を増やす
replicas:
  - name: hello-app
    count: 5

# イメージタグを変更
images:
  - name: nginx
    newTag: "1.26"

# パッチでリソースを追加
patches:
  - path: patches/deployment-patch.yaml
```

### パッチファイル

```yaml
# overlays/prod/patches/deployment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-app
spec:
  template:
    spec:
      containers:
        - name: hello
          resources:
            requests:
              memory: "64Mi"
              cpu: "100m"
            limits:
              memory: "128Mi"
              cpu: "200m"
```

### ビルド結果の確認

```bash
kubectl kustomize overlays/prod
```

base の Deployment に、パッチで指定したリソース制限がマージされた結果が出力されます。

### リモート base との差分を確認

```bash
diff -u \
  <(kubectl kustomize 'https://github.com/ono-hiroki/kustomize-base-example.git/bases/helloworld?ref=main') \
  <(kubectl kustomize overlays/prod)
```

出力例:
```diff
--- /dev/fd/11
+++ /dev/fd/12
@@ -2,7 +2,8 @@
 kind: Service
 metadata:
-  name: hello-service
+  labels:
+    env: production
+  name: prod-hello-service
 ...
 kind: Deployment
 metadata:
-  name: hello-app
+  labels:
+    env: production
+  name: prod-hello-app
 spec:
-  replicas: 3
+  replicas: 5
   ...
       containers:
-      - image: nginx:1.25
+      - image: nginx:1.26
         name: hello
+        resources:
+          limits:
+            cpu: 200m
+            memory: 128Mi
+          requests:
+            cpu: 100m
+            memory: 64Mi
```

### 期待した値が適用されているか確認

```bash
# レプリカ数が 5 になっているか
kubectl kustomize overlays/prod | grep -A2 "replicas:"

# イメージタグが 1.26 になっているか
kubectl kustomize overlays/prod | grep "image:"

# リソース制限が追加されているか
kubectl kustomize overlays/prod | grep -A8 "resources:"
```

---

## パッチの種類

### 1. Strategic Merge Patch（推奨）

Kubernetes ネイティブのマージ戦略を使用。配列は「名前」でマッチしてマージされます。

```yaml
# patches/deployment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp        # ← この名前で base とマッチ
  namespace: demo
spec:
  template:
    spec:
      containers:
        - name: myapp  # ← この名前でコンテナとマッチ
          image: new-image:v2
```

### 2. JSON Patch

RFC 6902 形式。配列のインデックス指定や、フィールドの追加・削除に便利。

```yaml
# kustomization.yaml
patches:
  - target:
      kind: Deployment
      name: myapp
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/image
        value: new-image:v2
      - op: add
        path: /metadata/annotations/new-key
        value: new-value
```

### どちらを選ぶ？

| ユースケース | 推奨 |
|------------|------|
| フィールドの値を変更 | Strategic Merge Patch |
| annotations に追加 | Strategic Merge Patch |
| 配列の特定インデックスを操作 | JSON Patch |
| フィールドを削除 | JSON Patch |

---

## Argo CD との連携

Argo CD は Kustomize をネイティブサポートしています。

### Application 定義

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/yourname/eks-private  # Private リポジトリ
    targetRevision: main
    path: overlays/production                          # overlay のパス
    # ↑ Argo CD が自動で kustomize build を実行
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 動作の流れ

```
1. Argo CD が Private リポジトリの overlays/production を取得
           ↓
2. kustomization.yaml 内の resources で Public base を取得
           ↓
3. Kustomize が base + patches をマージ
           ↓
4. マージ結果がクラスタにデプロイされる
```

---

## 注意事項

### 1. リモート参照のキャッシュ

Kustomize はリモートリソースをローカルにキャッシュします。最新を取得したい場合:

```bash
# キャッシュをクリア
rm -rf ~/.cache/kustomize

# または、ref にコミットハッシュを指定（推奨）
resources:
  - https://github.com/user/repo//path?ref=abc1234def
```

### 2. Private リポジトリへのアクセス

Private リポジトリを参照する場合、認証が必要です。

```bash
# git credential を設定
git config --global credential.helper store

# または SSH URL を使用
resources:
  - git@github.com:user/private-repo.git//path?ref=main
```

Argo CD の場合は、リポジトリを登録:

```bash
argocd repo add https://github.com/user/private-repo \
  --username <username> \
  --password <token>
```

### 3. ref の指定は必須

本番環境では必ず `?ref=` を指定してください。指定しないと予期せぬ変更が適用される可能性があります。

```yaml
# Bad: ref なし（デフォルトブランチの HEAD を参照）
resources:
  - https://github.com/user/repo//path

# Good: タグを指定
resources:
  - https://github.com/user/repo//path?ref=v1.0.0

# Good: コミットハッシュを指定（最も安全）
resources:
  - https://github.com/user/repo//path?ref=abc1234def5678
```

---

## まとめ

| 項目 | 説明 |
|------|------|
| **基本構文** | `https://github.com/user/repo//path?ref=tag` |
| **区切り** | `//` でリポジトリとパスを区切る |
| **バージョン固定** | `?ref=` でブランチ/タグ/ハッシュを指定 |
| **ユースケース** | Public base + Private overlay で機密情報を分離 |
| **Argo CD 連携** | Application の path に overlay を指定するだけ |

---

## 参考リンク

- [Kustomize - Remote Targets](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/resource/)
- [Argo CD - Kustomize](https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/)
