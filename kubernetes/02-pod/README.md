# はじめてのPodをnginxで動かす

Kubernetes の最小デプロイ単位である Pod を kubectl コマンドで操作する。
nginx コンテナを使って Pod の起動・確認・削除を実践する。

---

## Pod とは

Kubernetes ではコンテナを直接扱わず、Pod という単位で管理する。
Pod は1つ以上のコンテナをまとめた「コンテナのラッパー」で、同じ Pod 内のコンテナはネットワークとストレージを共有できる。

まずは 1 Pod = 1 コンテナのシンプルな構成で操作に慣れる。

---

## 環境セットアップ

### クラスターの確認

Docker Desktop で Kubernetes クラスターが起動していることを確認する。

```bash
kubectl cluster-info
```

### kubectl のエイリアス設定（推奨）

`kubectl` を `k` で呼び出せるようにエイリアスを設定すると便利。
Kubernetes 界隈ではほぼ標準的な慣習で、CKA/CKAD 認定試験でもデフォルトで用意されている。

```bash
# ~/.zshrc に追加
cat >> ~/.zshrc << 'EOF'

# kubectl alias
alias k='kubectl'
source <(kubectl completion zsh)
compdef k=kubectl
EOF

# 設定を反映
source ~/.zshrc
```

以降は `k` を使用する。

---

## Pod を動かしてみる

### Pod の起動 (kubectl run)

`nginx` という名前の Pod を起動する。

```bash
k run nginx --image=nginx:latest
```

### Pod の確認

#### Pod の一覧を確認 (kubectl get pod)

```bash
k get pod
```

STATUS が `Running` になっていれば OK。

#### Pod の詳細情報を確認 (kubectl describe pod)

```bash
k describe pod nginx
```

Events の項目は Pod が起動しない時のトラブルシュートに役立つ。

#### コンテナのログを確認 (kubectl logs)

```bash
# ログを表示
k logs nginx

# リアルタイムでフォロー（tail -f 的な）
k logs -f nginx

# 直近の行数を指定
k logs --tail=100 nginx
```

**describe vs logs:**

| コマンド | 用途 |
|---|---|
| `k describe pod` | Pod のイベント・状態（起動失敗の原因など） |
| `k logs` | コンテナ内アプリのログ（stdout/stderr） |

### Pod を削除 (kubectl delete pod)

```bash
k delete pod nginx
```

削除されたか確認:

```bash
k get pod
```

---

## Namespace でリソースを整理する

Namespace は Kubernetes リソースを論理的に分離するために使用する。

### Namespace の確認

全 Namespace の Pod を確認:

```bash
k get pod --all-namespaces
```

Namespace 一覧を確認:

```bash
k get namespaces
```

| Namespace | 説明 |
|-----------|------|
| default | デフォルトの Namespace。指定がない場合はここが使われる |
| kube-node-lease | ノードの死活監視用 lease リソースを管理 |
| kube-public | 誰でも読み取り可能なリソース用 |
| kube-system | Kubernetes のシステムコンポーネント用 |

### Namespace を作成 (kubectl create namespace)

```bash
k create namespace dev
```

### 特定の Namespace に Pod を作成

#### 方法1: --namespace オプションを使う

```bash
k run nginx --image=nginx:latest --namespace dev
# または
k run nginx --image=nginx:latest -n dev
```

#### 方法2: context で Namespace を設定する

現在の context 設定を確認:

```bash
k config get-contexts
```

デフォルト Namespace を変更:

```bash
k config set-context --current --namespace=dev
```

変更後は `-n` オプションなしで `dev` が使われる。

---

## nginx にアクセスしてみる

Pod が正しく動作しているか確認する。

1. **クラスター内から確認** - 別の Pod から curl でアクセス
2. **コンテナを操作** - 中に入って HTML を編集
3. **ホストから確認** - port-forward でブラウザからアクセス

### Pod の IP アドレスを確認

```bash
k get pod nginx -n dev --output wide
```

### クラスター内からリクエストする

ホストマシンから Pod の IP に直接アクセスはできない。
同じクラスター内の Pod 同士であれば IP で直接通信できる。

```
┌─────────────────────────────────────────────────┐
│  Kubernetes Cluster                             │
│                                                 │
│   curl-pod ──HTTP──> nginx (10.1.0.x:80)       │
│                                                 │
└─────────────────────────────────────────────────┘
        ↑
        │ 直接アクセス不可
        │
   ホストマシン
```

curl 用の Pod を立ち上げて、その中から nginx にリクエストしてみる。

#### 1. curl 用 Pod を起動

```bash
k run curl-pod --image=curlimages/curl:latest -n dev -- sleep 3600
```

#### 2. Pod が起動したか確認

```bash
k get pod curl-pod -n dev
```

STATUS が `Running` になるまで待つ。

#### 3. curl-pod に入ってリクエスト

```bash
k exec -it curl-pod -n dev -- sh
```

シェル内で:

```bash
curl http://<PodのIP>
```

nginx の HTML が返ってくれば成功。`exit` でシェルを抜ける。

#### 4. curl-pod を削除

```bash
k delete pod curl-pod -n dev
```

### コンテナに入る (kubectl exec)

Pod の中のコンテナにシェルで入ることができる。

```bash
k exec -it nginx -n dev -- /bin/bash
```

### コンテナ内で HTML を編集する

nginx の最小イメージには vim/vi/nano などのエディタが入っていない。
`cat` コマンドで上書きする。

```bash
cat > /usr/share/nginx/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Hello K8s</title></head>
<body><h1>Hello Kubernetes!</h1></body>
</html>
EOF
```

### ホストからアクセスする (kubectl port-forward)

`kubectl port-forward` で Pod のポートをホストに転送する。

```bash
k port-forward pod/nginx 8080:80 -n dev
```

別ターミナルで確認:

```bash
curl http://localhost:8080/
```

ブラウザで http://localhost:8080/ にアクセスしても OK。

#### Docker の `-p` オプションとの違い

| | Docker `-p` | kubectl port-forward |
|---|---|---|
| 仕組み | コンテナ起動時にホストのポートにバインド | kubectl プロセスがプロキシとして動作 |
| 永続性 | コンテナが動いている間有効 | コマンド終了で転送も終了 |
| 確認方法 | `docker container ls` の PORTS に表示 | 表示されない |

```
[localhost:8080] → [kubectl] → [K8s API] → [Pod:80]
```

`port-forward` は開発・デバッグ用の一時的な手段。
Kubernetes で外部公開する正式な方法は Service（NodePort/LoadBalancer）や Ingress を使う。

---

## クリーンアップ

### Pod を削除

```bash
k -n dev delete pod nginx
```

確認:

```bash
k get pod -n dev
```

### Namespace を削除

```bash
k delete namespace dev
```

---

## 参考資料

- [Pods | Kubernetes](https://kubernetes.io/docs/concepts/workloads/pods/)
- [Namespaces | Kubernetes](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
