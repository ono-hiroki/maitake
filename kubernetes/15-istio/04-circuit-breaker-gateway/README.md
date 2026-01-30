# サーキットブレーカーと Gateway

サーキットブレーカーで過負荷を防止し、Gateway で外部からメッシュ内サービスにアクセスします。

> **Note**: 本ガイドでは `kubectl` のエイリアスとして `k` を使用しています。

## 前提条件

- Kubernetes クラスタが稼働していること
- Istio がインストール済みであること（[セットアップ手順](../README.md#セットアップ)）

---

## 準備

```bash
k label namespace default istio-injection=enabled --overwrite

# Bookinfo アプリをデプロイ
k apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/bookinfo/platform/kube/bookinfo.yaml
k get pods -w

# fortio と httpbin をデプロイ
k apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/httpbin/sample-client/fortio-deploy.yaml
k apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/httpbin/httpbin.yaml
k get pods -l app=httpbin -w
```

---

## Part 1: サーキットブレーカー

Istio のサーキットブレーカーは 2 つの仕組みで構成されます:

- **connectionPool**: 接続数制限。上限を超えると即座に 503 を返す
- **outlierDetection**: 異常検出。エラーが続く Pod を一時的に除外する

### 1. サーキットブレーカーを設定

接続数を厳しく制限します。

```bash
k apply -f manifests/httpbin-circuit-breaker.yaml
```

```yaml
# manifests/httpbin-circuit-breaker.yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: httpbin
spec:
  host: httpbin
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 1           # TCP接続を1に制限
      http:
        http1MaxPendingRequests: 1  # 待機リクエストを1に制限
        maxRequestsPerConnection: 1 # 1接続1リクエスト
    outlierDetection:
      consecutive5xxErrors: 1       # 1回の5xxで除外
      interval: 1s
      baseEjectionTime: 30s
      maxEjectionPercent: 100
```

### 2. サーキットブレーカーの動作確認

同時接続数を超えるリクエストを送信します。

```bash
k exec deploy/fortio-deploy -c fortio -- \
  fortio load -c 3 -qps 0 -n 20 -loglevel Warning \
  http://httpbin:8000/get
```

結果:

```
Code 200 : 2 (10.0 %)   ← 成功
Code 503 : 18 (90.0 %)  ← サーキットブレーカーで拒否
```

`maxConnections: 1` を超えたリクエストが即座に 503 で拒否されています。

---

## Part 2: Gateway で外部からアクセス

### 3. Gateway を設定

```bash
k apply -f manifests/bookinfo-gateway.yaml
```

```yaml
# manifests/bookinfo-gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: bookinfo-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - "*"
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: bookinfo
spec:
  hosts:
    - "*"
  gateways:
    - bookinfo-gateway
  http:
    - match:
        - uri:
            exact: /productpage
        - uri:
            prefix: /static
        - uri:
            exact: /login
        - uri:
            exact: /logout
        - uri:
            prefix: /api/v1/products
      route:
        - destination:
            host: productpage
            port:
              number: 9080
```

### 4. ポートフォワードでアクセス

```bash
k port-forward -n istio-system svc/istio-ingressgateway 8080:80
```

http://localhost:8080/productpage を開き、Bookinfo アプリが表示されれば成功です。

---

## クリーンアップ

```bash
k delete gateway bookinfo-gateway
k delete virtualservice bookinfo
k delete destinationrule httpbin
k delete -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/httpbin/httpbin.yaml
k delete -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/bookinfo/platform/kube/bookinfo.yaml
k delete -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/httpbin/sample-client/fortio-deploy.yaml
```
