# 03. Manifest ファイルで Pod を定義する

YAML 形式の manifest ファイルを使って Pod を宣言的に管理する。
毎回コマンドを手打ちするのは手間がかかるし、どんな設定で起動したのか後から確認することも難しい。
manifest ファイルを使えば、いつでも同じ構成を簡単に再現できる。

---

## ファイル構成

```
03-manifest/
├── README.md
└── manifests/
    ├── pod.yaml           # シンプルな Pod
    └── pod-sidecar.yaml   # サイドカーパターン
```

---

## Manifest の基本構造

manifest の構造を nginx の Pod を例に見てみる。

```yaml
# API バージョン (<group>/<version> の形式、v1 は core グループ)
apiVersion: v1
# リソースの種類
kind: Pod
metadata:
  # リソース名
  name: nginx
  # 所属する Namespace
  namespace: dev
# リソースの具体的な設定 (リソースの種類によって異なる)
spec:
  # Pod 内のコンテナ一覧
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
```

- 一部のリソースでは `metadata` や `spec` がない場合もある
- 指定可能な `kind` や `apiVersion` は `kubectl api-resources` で確認できる

### 各フィールドの説明

| 項目 | 説明 |
|---|---|
| `apiVersion: v1` | API のバージョン（v1 は core グループ） |
| `kind: Pod` | リソースの種類 |
| `metadata.name` | Pod の名前 |
| `metadata.namespace` | Pod を作成する Namespace |
| `spec.containers` | コンテナのリスト |
| `spec.containers[].name` | コンテナの名前 |
| `spec.containers[].image` | 使用するコンテナイメージ |
| `spec.containers[].ports` | コンテナが待ち受けるポート |

---

## シンプルな Pod をデプロイする

### Namespace の作成

manifest で指定している Namespace `dev` を事前に作成しておく必要がある。

```bash
k create namespace dev
```

### Manifest の適用

`kubectl apply` コマンドで manifest を適用する。

```bash
k apply -f manifests/pod.yaml
```

### 動作確認

Pod が正しく動作しているか確認する。

まず Pod の状態を確認:

```bash
k get pod -n dev
```

```
NAME    READY   STATUS    RESTARTS   AGE
nginx   1/1     Running   0          10s
```

STATUS が `Running` になっていれば OK。

port-forward でローカルからアクセスできるようにする:

```bash
k port-forward -n dev pod/nginx 8080:80
```

別のターミナルを開いて確認:

```bash
curl http://localhost:8080
```

nginx のデフォルトページが表示されれば成功。確認が終わったら `Ctrl+C` で port-forward を終了する。

### Pod の削除

次のセクションに進む前に Pod を削除しておく。

```bash
k delete -f manifests/pod.yaml
```

---

## サイドカーパターンを試す

Pod は複数のコンテナを含むことができる。
メインのコンテナを補助する形で動作するコンテナを「サイドカー」と呼ぶ。

### ログ転送の例

`manifests/pod-sidecar.yaml` では、nginx のアクセスログを共有ボリュームに出力し、サイドカーコンテナがそのログを読み取る。
実務ではこのパターンで Fluentd や Fluent Bit などのログ収集ツールにログを転送する。

### 構成のポイント

| 項目 | 説明 |
|---|---|
| `spec.containers` | 2つのコンテナを定義 |
| `spec.volumes` | Pod 内で共有するボリュームを定義 |
| `volumeMounts` | 各コンテナでボリュームをマウントする場所を指定 |
| `emptyDir` | Pod 起動時に作成される一時的な空のディレクトリ |

この構成では:
- `nginx` コンテナがアクセスログを `/var/log/nginx/access.log` に出力
- `log-shipper` コンテナが同じボリュームをマウントしてログを読み取り

### 適用と動作確認

```bash
k apply -f manifests/pod-sidecar.yaml
```

Pod の状態を確認する。READY が `2/2` になっていることを確認:

```bash
k get pod -n dev
```

```
NAME                 READY   STATUS    RESTARTS   AGE
nginx-with-sidecar   2/2     Running   0          10s
```

port-forward で nginx にアクセスできるようにする:

```bash
k port-forward -n dev pod/nginx-with-sidecar 8080:80
```

別のターミナルでリクエストを送る:

```bash
curl http://localhost:8080
```

### サイドカーのログを確認

`-c` オプションでコンテナを指定し、`-f` オプションでリアルタイムにログを確認する。

```bash
k logs -f -n dev nginx-with-sidecar -c log-shipper
```

この状態で別のターミナルから `curl http://localhost:8080` を実行すると、リアルタイムでログが流れてくる:

```
10.1.0.1 - - [10/Jan/2025:12:00:00 +0000] "GET / HTTP/1.1" 200 615 "-" "curl/8.0.0" "-"
10.1.0.1 - - [10/Jan/2025:12:00:05 +0000] "GET / HTTP/1.1" 200 615 "-" "curl/8.0.0" "-"
```

確認が終わったら `Ctrl+C` でログのフォローを終了し、port-forward も終了して Pod を削除する:

```bash
k delete -f manifests/pod-sidecar.yaml
```

---

## クリーンアップ

最後に Namespace を削除する。

```bash
k delete namespace dev
```

---

## まとめ

manifest ファイルを使うメリット:
- **再現性**: 同じ構成をいつでも正確に再現できる
- **バージョン管理**: Git で変更履歴を追跡できる
- **共有**: チームメンバーと設定を簡単に共有できる
- **宣言的管理**: あるべき状態をコードで定義できる

学んだこと:
- manifest の基本構造（apiVersion、kind、metadata、spec）
- `kubectl apply -f` で manifest を適用する方法
- 複数コンテナを持つ Pod（サイドカーパターン）の定義方法

---

## 参考資料

- [API概要 | Kubernetes](https://kubernetes.io/ja/docs/reference/using-api/)
