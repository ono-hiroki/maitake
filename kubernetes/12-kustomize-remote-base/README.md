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

実際に公開されている Kustomize のサンプルを参照して試してみましょう。

### Step 1: ローカルに overlay を作成

```bash
mkdir -p ~/kustomize-remote-demo/overlays/dev
cd ~/kustomize-remote-demo/overlays/dev
```

### Step 2: リモート base を参照する kustomization.yaml を作成

```yaml
# ~/kustomize-remote-demo/overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Kustomize公式サンプルのhelloWorldを参照
resources:
  - https://github.com/kubernetes-sigs/kustomize//examples/helloWorld?ref=master

# ローカルでカスタマイズ
namePrefix: dev-

commonLabels:
  env: development
```

### Step 3: ビルドして確認

```bash
kustomize build .
```

出力例:
```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: hello
    env: development          # ← 追加されたラベル
  name: dev-the-service       # ← dev- プレフィックス付き
spec:
  ...
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: hello
    env: development          # ← 追加されたラベル
  name: dev-the-deployment    # ← dev- プレフィックス付き
spec:
  ...
```

### Step 4: クリーンアップ

```bash
rm -rf ~/kustomize-remote-demo
```

---

## 実用例: Public base + Private overlay

これがユースケースの本命です。

### シナリオ

- **Public リポジトリ**: 機密情報なしの base マニフェスト（ポートフォリオとして公開可能）
- **Private リポジトリ**: 本番環境の値を含む overlay（ACM ARN、ドメイン名、IAM ロール ARN など）

### ディレクトリ構成

```
# Public: https://github.com/yourname/eks-portfolio
eks-portfolio/
└── base/
    ├── kustomization.yaml
    ├── deployment.yaml      # image: PLACEHOLDER
    └── ingress.yaml         # host: example.com

# Private: ローカルまたは Private リポジトリ
eks-private/
└── overlays/
    └── production/
        ├── kustomization.yaml   # Public base を参照
        └── patches/
            ├── deployment-patch.yaml
            └── ingress-patch.yaml
```

### Public base の例

```yaml
# eks-portfolio/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - ingress.yaml
```

```yaml
# eks-portfolio/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: PLACEHOLDER_IMAGE  # ← 本番値はパッチで上書き
          ports:
            - containerPort: 8080
```

```yaml
# eks-portfolio/base/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  namespace: demo
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    # ACM ARN はパッチで追加
spec:
  ingressClassName: alb
  rules:
    - host: example.com  # ← 本番値はパッチで上書き
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: myapp
                port:
                  number: 80
```

### Private overlay の例

```yaml
# eks-private/overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# リモートの Public base を参照
resources:
  - https://github.com/yourname/eks-portfolio//base?ref=main

# パッチで機密値を上書き
patches:
  - path: patches/deployment-patch.yaml
  - path: patches/ingress-patch.yaml
```

```yaml
# eks-private/overlays/production/patches/deployment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: demo
spec:
  template:
    spec:
      containers:
        - name: myapp
          image: 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/myapp:v1.0.0
```

```yaml
# eks-private/overlays/production/patches/ingress-patch.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  namespace: demo
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-northeast-1:123456789012:certificate/xxxxx
    external-dns.alpha.kubernetes.io/hostname: app.mydomain.com
spec:
  rules:
    - host: app.mydomain.com
```

### ビルド結果の確認

```bash
cd eks-private/overlays/production
kustomize build .
```

Public base の PLACEHOLDER 値が、Private patch の本番値にマージされた結果が出力されます。

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
