# サイドカー注入

Pod に Envoy プロキシが自動注入され、すべての通信が Envoy を経由することを確認します。

> **Note**: 本ガイドでは `kubectl` のエイリアスとして `k` を使用しています。

## 前提条件

- Kubernetes クラスタが稼働していること
- Istio がインストール済みであること（[セットアップ手順](../README.md#セットアップ)）

---

## 1. nginx と curl をデプロイ（サイドカーなし）

```bash
# nginx サーバーをデプロイ
k run nginx --image=nginx --port=80
k expose pod nginx --port=80

# curl クライアントをデプロイ
k run curl --image=curlimages/curl --command -- sleep infinity

# Pod が起動するまで待つ
k get pods -w
```

`READY` 列が **`1/1`**（アプリコンテナのみ）であることを確認します。

```bash
# サイドカーなしでリクエスト
k exec curl -- curl -sI http://nginx | grep -E "^HTTP|^[Ss]erver:"
```

```
HTTP/1.1 200 OK
Server: nginx/1.x.x
```

`Server: nginx` = nginx が直接応答しています。

---

## 2. サイドカー自動注入を有効化

```bash
k label namespace default istio-injection=enabled

# 確認
k get namespace -L istio-injection
```

> **Note**: ラベルは**新しく作成される Pod** に対して適用されます。既存の Pod には影響しません。

---

## 3. Pod を再作成してサイドカーを注入

```bash
k delete pod nginx curl

k run nginx --image=nginx --port=80
k run curl --image=curlimages/curl --command -- sleep infinity

k get pods -w
```

`READY` 列が **`2/2`**（アプリコンテナ + istio-proxy）になることを確認します。

---

## 4. サイドカー注入の確認

```bash
# コンテナの名前を確認
k get pod nginx -o custom-columns="\
INIT_CONTAINERS:.spec.initContainers[*].name,\
CONTAINERS:.spec.containers[*].name"
```

Istio 1.28 + Kubernetes 1.28 以降では、`istio-proxy` は `initContainers` に `restartPolicy: Always` で定義されます（ネイティブサイドカー）。

```bash
# istio-proxy の restartPolicy を確認
k get pod nginx -o jsonpath='{.spec.initContainers[?(@.name=="istio-proxy")].restartPolicy}'
# → Always
```

```
Before (1/1):
┌─────────────────────────────────────┐
│ Pod                                 │
│ spec.containers:                    │
│ ┌─────────────────────────────────┐ │
│ │ nginx (アプリ)                  │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘

After (2/2):
┌─────────────────────────────────────┐
│ Pod                                 │
│ spec.initContainers:                │
│ ┌─────────────────────────────────┐ │
│ │ istio-init (iptables設定後終了) │ │
│ ├─────────────────────────────────┤ │
│ │ istio-proxy (restartPolicy:     │ │
│ │   Always で継続実行)            │ │
│ └─────────────────────────────────┘ │
│ spec.containers:                    │
│ ┌─────────────────────────────────┐ │
│ │ nginx (アプリ)                  │ │
│ └─────────────────────────────────┘ │
│ iptables により全通信が             │
│ istio-proxy を経由                  │
└─────────────────────────────────────┘
```

---

## 5. Envoy 経由の通信を確認

```bash
k exec curl -- curl -sI http://nginx | grep -E "^HTTP|^[Ss]erver:|^x-envoy"
```

```
HTTP/1.1 200 OK
server: envoy
x-envoy-upstream-service-time: 1
```

| 状態 | Server ヘッダー | 説明 |
|------|-----------------|------|
| サイドカーなし | `Server: nginx` | nginx が直接応答 |
| サイドカーあり | `server: envoy` | Envoy 経由で応答 |

---

## クリーンアップ

```bash
k delete pod nginx curl
k delete svc nginx
```
