# オブザーバビリティ

Istio を導入すると、**アプリのコード変更なし**でオブザーバビリティが得られます。すべての通信が Envoy を経由するため、Envoy がメトリクスとトレースを自動収集します。

> **Note**: 本ガイドでは `kubectl` のエイリアスとして `k` を使用しています。

## 前提条件

- Kubernetes クラスタが稼働していること
- Istio がインストール済みであること（[セットアップ手順](../README.md#セットアップ)）

---

## 仕組み

```
                Envoy (istio-proxy)
                       │
       ┌───────────────┴───────────────┐
       ↓                               ↓
    メトリクス                      トレース
       │                               │
       ↓                               ↓
  Prometheus                        Jaeger
       │                               │
       └───────────┬───────────────────┘
                   ↓
                Kiali
```

| ツール | 役割 |
|--------|------|
| **Prometheus** | メトリクス収集・保存（Envoy の `/stats` をスクレイプ） |
| **Jaeger** | トレース収集・保存（Envoy からスパンを受信） |
| **Kiali** | 可視化ダッシュボード（Prometheus + Istio 設定を読み取り） |

| 種類 | 内容 | 用途 |
|------|------|------|
| **メトリクス** | 集計データ（数値） | 「過去1分間に100リクエスト、平均50ms」 |
| **トレース** | 個別リクエストの追跡 | 「このリクエストは A→B→C を経由し、B で 30ms かかった」 |

---

## 1. Bookinfo アプリをデプロイ

可視化には複数サービス間の通信が必要なため、Bookinfo を使用します。

```
productpage → details
           → reviews → ratings
```

```bash
k label namespace default istio-injection=enabled --overwrite

k apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/bookinfo/platform/kube/bookinfo.yaml

# Pod が全て 2/2 で Running になるまで待つ
k get pods -w
```

---

## 2. Envoy のメトリクスを確認

```bash
k exec deploy/productpage-v1 -c istio-proxy -- curl -s localhost:15090/stats/prometheus | grep istio_requests_total | head -5
```

`istio_requests_total` などのメトリクスが表示されます。

---

## 3. Prometheus / Kiali をインストール

```bash
# Prometheus（メトリクス収集）
k apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/addons/prometheus.yaml

# Kiali（サービスメッシュ可視化）
k apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/addons/kiali.yaml

# 起動を待つ
k get pods -n istio-system -w
```

---

## 4. トラフィックを発生させる

**別のターミナル**で以下を実行:

```bash
while true; do
  k exec deploy/productpage-v1 -c istio-proxy -- curl -s http://productpage:9080/productpage > /dev/null
  sleep 1
done
```

---

## 5. Kiali ダッシュボードを開く

```bash
istioctl dashboard kiali
```

1. 左メニューから **「Graph」** を選択
2. Namespace を **「default」** に変更
3. Display で **「Traffic Animation」** をオンにする

| 確認項目 | 説明 |
|----------|------|
| サービス間の依存関係 | どのサービスがどのサービスを呼んでいるか |
| リクエストの成功率 | 緑 = 成功、赤 = エラー |
| レイテンシ | 各サービスの応答時間 |
| トラフィック量 | 線の太さでリクエスト数を表現 |

---

## 6. Jaeger で分散トレーシング

```bash
k apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/addons/jaeger.yaml
k get pods -n istio-system -l app=jaeger -w

istioctl dashboard jaeger
```

1. **Service** ドロップダウンから `productpage.default` を選択
2. **Find Traces** をクリック

トレースをクリックすると、リクエストの経路が可視化されます:

```
productpage ─────────────────────────────────────→
    │
    ├─→ details ──────→
    │
    └─→ reviews ───────────────→
           │
           └─→ ratings ──→
```

各バーの長さが処理時間を表します。

| 状況 | 使うツール |
|------|-----------|
| 全体的なトラフィック傾向を見たい | Kiali（メトリクス） |
| 特定のリクエストがなぜ遅いか調べたい | Jaeger（トレース） |

---

## クリーンアップ

```bash
k delete -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/bookinfo/platform/kube/bookinfo.yaml
k delete -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/addons/kiali.yaml
k delete -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/addons/prometheus.yaml
k delete -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/addons/jaeger.yaml
```
