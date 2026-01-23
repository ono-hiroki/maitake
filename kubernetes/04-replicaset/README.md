# ReplicaSetでPodを管理する

ReplicaSet を使って Pod の数を維持し、自己修復機能とスケーラビリティを体験する。

> **注意**: 実際の運用では ReplicaSet 単体ではなく Deployment で管理するのが一般的。ただし Deployment は内部で ReplicaSet を利用しているため、ReplicaSet の動作を理解しておくことは重要。

---

## ファイル構成

```
04-replicaset/
├── README.md
└── manifests/
    └── nginx-replicaset.yaml
```

---

## Pod だけで運用すると何が困るか

単一の Pod で nginx を動かす場合、以下の問題がある。

1. **障害に弱い**: Pod がクラッシュするとサービスが停止。手動で再作成するまで復旧しない
2. **スケールできない**: アクセスが増えても Pod は1つのまま
3. **状態管理が煩雑**: 複数の Pod を手動で管理すると把握が大変

---

## ReplicaSet が解決すること

ReplicaSet は「指定した数の Pod を常に維持する」リソース。

- **自動復旧**: Pod が落ちても、自動的に新しい Pod を作成して指定数を維持
- **スケーリング**: `replicas` の値を変えるだけで Pod 数を増減
- **宣言的管理**: あるべき状態を manifest で定義し、Kubernetes が自動で維持

### ReplicaSet と Pod の関係

```
┌─────────────────────────────────────────────────────────┐
│  ReplicaSet (nginx-replicaset)                          │
│                                                         │
│  selector:           replicas: 3                        │
│    matchLabels:          │                              │
│      app: nginx          │                              │
│          │               │                              │
└──────────┼───────────────┼──────────────────────────────┘
           │               │
           ▼               ▼
┌─────────────────────────────────────────────────────────┐
│  管理対象の Pod（ラベル: app=nginx）                     │
│                                                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
│  │ nginx-xxxxx │ │ nginx-yyyyy │ │ nginx-zzzzz │       │
│  │ app=nginx   │ │ app=nginx   │ │ app=nginx   │       │
│  └─────────────┘ └─────────────┘ └─────────────┘       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  管理対象外（ラベル不一致）                              │
│                                                         │
│  ┌─────────────┐                                        │
│  │ other-pod   │  ← ReplicaSet は干渉しない            │
│  │ app=other   │                                        │
│  └─────────────┘                                        │
└─────────────────────────────────────────────────────────┘
```

ポイント:
- ReplicaSet は `selector` で指定したラベルを持つ Pod だけを管理する
- `template` に基づいて新しい Pod を作成する
- `replicas` で指定した数を常に維持しようとする

---

## ReplicaSet をデプロイする

### Namespace を作成

```bash
k create namespace dev
```

### ReplicaSet を適用

```bash
k apply -f manifests/nginx-replicaset.yaml
```

### 状態を確認

ReplicaSet の状態:

```bash
k get rs -n dev
```

```
NAME               DESIRED   CURRENT   READY   AGE
nginx-replicaset   3         3         3       30s
```

Pod も確認:

```bash
k get pod -n dev
```

```
NAME                       READY   STATUS    RESTARTS   AGE
nginx-replicaset-xxxxx     1/1     Running   0          45s
nginx-replicaset-yyyyy     1/1     Running   0          45s
nginx-replicaset-zzzzz     1/1     Running   0          45s
```

全リソースをまとめて確認:

```bash
k get all -n dev
```

### describe で詳細を確認

トラブルシューティングで重宝するコマンド。

```bash
k describe rs nginx-replicaset -n dev
```

確認できる主な情報:

| 項目 | 説明 |
|------|------|
| `Selector` | 管理対象 Pod を識別するラベル条件 |
| `Replicas` | 現在の Pod 数 / 期待する Pod 数 |
| `Pods Status` | Running/Waiting/Succeeded/Failed の内訳 |
| `Events` | Pod 作成・削除などの操作履歴 |

---

## スケーリングを試す

Pod 数を変更する方法は3つある。

### 方法1: kubectl scale で即座に変更

開発中やトラブル対応など、すぐに Pod 数を変えたいときに使う。

```bash
k scale rs nginx-replicaset -n dev --replicas=5
```

### 方法2: kubectl edit で直接編集

動いているリソースを直接変更する。

```bash
k edit rs nginx-replicaset -n dev
```

エディタが起動し、保存して終了すると変更が反映される。

### 方法3: manifest を編集して apply

本番運用では、manifest を変更して Git で管理する方法が推奨される。

```diff
spec:
-  replicas: 5
+  replicas: 2
```

```bash
k apply -f manifests/nginx-replicaset.yaml
```

---

## 自己修復を試す

### Pod を監視する

別のターミナルで Pod の状態を監視:

```bash
k get pod -n dev --watch
```

### Pod を削除してみる

動いている Pod を削除:

```bash
k delete pod nginx-replicaset-xxxxx -n dev
```

監視中のターミナルを見ると、以下のような変化が観察できる:

```
NAME                       READY   STATUS        RESTARTS   AGE
nginx-replicaset-xxxxx     1/1     Terminating   0          10m
nginx-replicaset-yyyyy     1/1     Running       0          10m
nginx-replicaset-zzzzz     1/1     Running       0          10m
nginx-replicaset-abc12     0/1     Pending       0          0s
nginx-replicaset-abc12     0/1     ContainerCreating   0   0s
nginx-replicaset-abc12     1/1     Running       0          2s
```

Pod が削除されると、すぐに新しい Pod が作成されて指定数が維持される。

---

## ラベルセレクターの仕組みを確認する

### 同じラベルを持つ Pod を追加する

ReplicaSet が管理するラベル（`app=nginx`）を持つ Pod を手動で作成:

```bash
k run extra-nginx --image=nginx:latest -n dev --labels="app=nginx"
```

作成した Pod はすぐに削除される。ReplicaSet は指定数を維持するため、余分な Pod は不要と判断される。

### 異なるラベルを持つ Pod を追加する

別のラベル（`app=other`）で Pod を作成:

```bash
k run other-nginx --image=nginx:latest -n dev --labels="app=other"
```

```bash
k get pod -n dev
```

```
NAME                       READY   STATUS    RESTARTS   AGE
nginx-replicaset-xxxxx     1/1     Running   0          15m
nginx-replicaset-yyyyy     1/1     Running   0          15m
other-nginx                1/1     Running   0          5s
```

この Pod は削除されない。ラベルが異なるため、ReplicaSet の管理対象外。

確認後、削除:

```bash
k delete pod other-nginx -n dev
```

---

## よくある失敗パターン

### selector と template のラベルが一致しない

```yaml
spec:
  selector:
    matchLabels:
      app: nginx        # selector は「app: nginx」
  template:
    metadata:
      labels:
        app: web-server # template は「app: web-server」← 不一致！
```

このエラーが発生する:

```
The ReplicaSet "nginx-rs-broken" is invalid: spec.template.metadata.labels:
Invalid value: `selector` does not match template `labels`
```

`selector.matchLabels` と `template.metadata.labels` は必ず一致させること。

---

## クリーンアップ

ReplicaSet を削除すると、管理下の Pod も一緒に削除される。

```bash
k delete -f manifests/nginx-replicaset.yaml
```

確認:

```bash
k get all -n dev
```

```
No resources found in dev namespace.
```

---

## コマンドまとめ

| コマンド | 説明 |
|---------|------|
| `k get rs -n dev` | ReplicaSet の確認 |
| `k get all -n dev` | 全リソースの確認 |
| `k scale rs <name> --replicas=N -n dev` | replica 数の変更 |
| `k edit rs <name> -n dev` | リソースの直接編集 |
| `k get pod -n dev --watch` | Pod の状態を監視 |
| `k describe rs <name> -n dev` | 詳細情報の確認 |

---

## 参考資料

- [ReplicaSet | Kubernetes](https://kubernetes.io/ja/docs/concepts/workloads/controllers/replicaset/)
