# Deploymentでアプリケーションを更新する

## はじめに

ReplicaSet を使えば Pod の数を維持できますが、アプリケーションを更新するときはどうでしょうか？イメージを新しくしたい場合、ReplicaSet だけでは手動で Pod を入れ替える必要があり、運用が大変です。

本記事では、まず ReplicaSet だけで運用したときの問題点を体験し、その後 Deployment を使ってローリングアップデートとロールバックを自動化する方法を学びます。

## 環境

> **Note**: 本ガイドでは `kubectl` のエイリアスとして `k` を使用しています。

### kind クラスターを作成

まず kind で Kubernetes クラスターを作成します。

```bash
kind create cluster
```

既存のクラスターがある場合は削除してから作成します。

```bash
kind delete cluster && kind create cluster
```

クラスターが正常に動作していることを確認します。

```bash
k cluster-info
```

**出力例:**

```
Kubernetes control plane is running at https://127.0.0.1:xxxxx
CoreDNS is running at https://127.0.0.1:xxxxx/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

### Namespace を用意

Deployment を作成する namespace を用意します。

```bash
k create namespace dev
```

---

## ReplicaSetだけで運用すると何が困るか

Deployment の必要性を理解するために、まず ReplicaSet だけで運用したときに何が困るのかを実際に体験してみましょう。

### ReplicaSet を作成する

まず確認用の ReplicaSet を作成します。

`./manifests/web-replicaset.yaml`:

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  labels:
    app: web-replicaset
  name: web-replicaset
  namespace: dev
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - image: nginx:latest
        name: web
```

適用します：

```bash
k apply -f ./manifests/web-replicaset.yaml
```

Pod が作成されたことを確認します：

```bash
k -n dev get pods -o wide
```

**出力例:**

```
NAME                   READY   STATUS    RESTARTS   AGE   IP           NODE
web-replicaset-abc12   1/1     Running   0          10s   10.244.0.5   kind-control-plane
web-replicaset-def34   1/1     Running   0          10s   10.244.0.6   kind-control-plane
web-replicaset-ghi56   1/1     Running   0          10s   10.244.0.7   kind-control-plane
```

### template を変更しても既存の Pod は更新されない

ReplicaSet の `template` のイメージを変更してみます。

`./manifests/web-replicaset.yaml` を編集：

```yaml
containers:
- image: nginx:1.27-alpine  # nginx:latest から変更
  name: web
```

適用します：

```bash
k apply -f ./manifests/web-replicaset.yaml
```

Pod のイメージを確認します：

```bash
k -n dev get pods -o=jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

**出力例:**

```
web-replicaset-abc12    nginx:latest
web-replicaset-def34    nginx:latest
web-replicaset-ghi56    nginx:latest
```

template を変更して apply しても、**既存の Pod は古いイメージ（nginx:latest）のまま**です。

### 手動で Pod を削除すると新しい template で再作成される

Pod を 1 つ削除してみます：

```bash
k -n dev delete pod $(k -n dev get pods -o jsonpath='{.items[0].metadata.name}')
```

再度イメージを確認します：

```bash
k -n dev get pods -o=jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

**出力例:**

```
web-replicaset-def34    nginx:latest
web-replicaset-ghi56    nginx:latest
web-replicaset-xyz99    nginx:1.27-alpine   # 新しく作成された Pod
```

削除された Pod の代わりに新しく作成された Pod だけが、新しいイメージ（nginx:1.27-alpine）になっています。

### ReplicaSet だけでは運用が大変

この挙動から、ReplicaSet だけでイメージを更新するには：

- **全ての Pod を手動で削除する**必要がある（ダウンタイム発生）
- または**ローリングアップデートを手動で管理**する必要がある（新旧の ReplicaSet のレプリカ数を調整）
- **ロールバックも同様に手動**で行う必要がある

これは運用上非常に面倒で、ミスも起きやすいです。

### 確認用 ReplicaSet の削除

Deployment の確認に進む前に、作成した ReplicaSet を削除します：

```bash
k delete -f ./manifests/web-replicaset.yaml
```

---

## Deploymentが解決すること

Deployment は ReplicaSet の上位リソースとして、以下の機能を提供します：

- **ローリングアップデートの自動化**: イメージを変更して `apply` するだけで、Pod が段階的に入れ替わる
- **ロールバックの簡略化**: `rollout undo` コマンド一発で前の状態に戻せる
- **更新戦略の制御**: 同時に何個の Pod を入れ替えるかを細かく設定できる

では、実際に Deployment を作成して動作を確認していきましょう。

## manifestを書いてデプロイする

### manifestファイルを作成する

`./manifests/web-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: web-deployment       # Deployment 自体に付けるラベル
  name: web-deployment        # Deployment の名前
  namespace: dev              # 作成先の namespace
spec:
  replicas: 3                 # 維持する Pod の数
  selector:
    matchLabels:
      app: web                # この labelをもつPod を管理対象とする
  strategy:
    type: RollingUpdate       # デプロイ戦略（RollingUpdate / Recreate）
    rollingUpdate:
      maxSurge: 1             # 更新中に追加で作成可能な Pod の最大数
      maxUnavailable: 1       # 更新中にダウンしていてもよい Pod の最大数
  template:                   # ここから下は Pod のテンプレート
    metadata:
      labels:
        app: web              # Pod に付けるラベル（selector.matchLabels と一致させる）
    spec:
      containers:
      - image: nginx:latest   # コンテナイメージ
        name: web             # コンテナの名前
```

### manifest の構造

Deployment の manifest は ReplicaSet とほとんど同じ構造ですが、`strategy` フィールドが追加されています。

| フィールド | 説明 |
|-----------|------|
| `metadata.name` | Deployment の名前 |
| `metadata.namespace` | Deployment を作成する namespace |
| `spec.replicas` | 維持する Pod のレプリカ数 |
| `spec.selector.matchLabels` | 管理対象の Pod を選択するラベル |
| `spec.strategy` | デプロイ戦略（後述） |
| `spec.template` | 作成する Pod のテンプレート |

### strategy（デプロイ戦略）

`strategy` フィールドで、Pod をどのように入れ替えるかを指定します。

#### Recreate（全置換）

```yaml
strategy:
  type: Recreate
```

全ての既存 Pod を**先に削除**してから、新しい Pod を作成します。

- **メリット**: 新旧バージョンが混在しないため、互換性の問題を回避できる
- **デメリット**: 全 Pod が停止する期間が発生する（ダウンタイム）
- **ユースケース**: データベースのスキーマ変更を伴うアップデートなど、新旧混在が許容できない場合

#### RollingUpdate（段階的置換）

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1       # 追加で作成してよい Pod 数
    maxUnavailable: 1 # 停止してよい Pod 数
```

既存の Pod を段階的に新しい Pod に置き換えます。

- **メリット**: 常に一定数の Pod が稼働しているため、ダウンタイムが発生しない
- **デメリット**: 更新中は新旧バージョンが混在する
- **ユースケース**: 通常のアプリケーションアップデート（ほとんどのケースでこちらを使用）

### maxSurge と maxUnavailable の考え方

`replicas: 3` の場合を例に考えます。

```
maxSurge: 1, maxUnavailable: 1 の場合

更新前: [old] [old] [old]     ← 3 Pod
更新中: [old] [old] [new]     ← 2〜4 Pod の範囲で推移
更新後: [new] [new] [new]     ← 3 Pod
```

| 設定 | 意味 | 上記例での値 |
|------|------|-------------|
| `maxSurge` | replicas を超えて作成できる数 | 最大 4 Pod まで存在可能 |
| `maxUnavailable` | replicas を下回ってよい数 | 最低 2 Pod は稼働 |

整数だけでなく `25%` のようにパーセンテージでも指定できます。大規模なクラスタでは割合指定が便利です。

---

### デプロイする

```bash
k apply -f ./manifests/web-deployment.yaml
```

適用後確認：

```bash
k -n dev get all
```

### 状態を確認する

```
NAME                                        READY   STATUS    RESTARTS   AGE
pod/web-deployment-5cd4b9b767-fksjk   1/1     Running   0          6s
pod/web-deployment-5cd4b9b767-hf2t5   1/1     Running   0          6s
pod/web-deployment-5cd4b9b767-hzcrb   1/1     Running   0          6s

NAME                                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/web-deployment   3/3     3            3           6s

NAME                                              DESIRED   CURRENT   READY   AGE
replicaset.apps/web-deployment-5cd4b9b767   3         3         3       6s
```

Deployment だけ作成しましたが、ReplicaSet も Pod も作成されています。これは Deployment が内部で ReplicaSet を生成し、その ReplicaSet が Pod を生成するという階層構造になっているためです。

## DeploymentとReplicaSetの関係

```
Deployment
    └── ReplicaSet（Deployment が自動生成）
            └── Pod（ReplicaSet が自動生成）
                    └── Container
```

この階層構造により、各リソースは自分の直下のリソースだけを管理すればよく、責務が明確に分離されています。

| リソース | 役割 | 管理対象 |
|----------|------|----------|
| **Deployment** | ローリングアップデートとロールバックの制御 | ReplicaSet |
| **ReplicaSet** | 指定数の Pod レプリカを維持 | Pod |
| **Pod** | コンテナの実行環境を提供 | Container |

Deployment を更新すると、新しい ReplicaSet が作成され、古い ReplicaSet のレプリカ数を減らしながら新しい ReplicaSet のレプリカ数を増やすことで、ローリングアップデートが実現されます。

## スケーリングを試す

Deployment 経由で Pod 数を変更すると、配下の ReplicaSet のレプリカ数も連動して変更されることを確認します。

### 確認すること

- Deployment の replicas を変更すると、Pod 数が増減する
- ReplicaSet の DESIRED/CURRENT も連動して変わる
- ReplicaSet を直接変更しても、Deployment によって元に戻される

### スケールアップ

```bash
k -n dev scale deployment web-deployment --replicas=5
```

変更後の状態を確認します：

```bash
k -n dev get all
```

**期待される結果:**

```
NAME                                  READY   STATUS    RESTARTS   AGE
pod/web-deployment-xxxxx-aaaaa        1/1     Running   0          10m
pod/web-deployment-xxxxx-bbbbb        1/1     Running   0          10m
pod/web-deployment-xxxxx-ccccc        1/1     Running   0          10m
pod/web-deployment-xxxxx-ddddd        1/1     Running   0          5s   # 新規
pod/web-deployment-xxxxx-eeeee        1/1     Running   0          5s   # 新規

NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/web-deployment   5/5     5            5           10m  # 5/5 に増加

NAME                                        DESIRED   CURRENT   READY   AGE
replicaset.apps/web-deployment-xxxxx        5         5         5       10m  # 5 に増加
```

Pod が 3 → 5 に増え、ReplicaSet の DESIRED/CURRENT も 5 に変わっていることを確認できます。

### 元に戻す

```bash
k -n dev scale deployment web-deployment --replicas=3
```

---

## ローリングアップデートとロールバックを試す

### デプロイ（イメージの更新）

nginx のタグを変えてデプロイしてみましょう。

**./manifests/web-deployment.yaml の変更**

```yaml
containers:
- image: nginx:1.27-alpine3.19  # nginx:latest から変更
  name: web
```

適用する前に watch しておくと変化がわかりやすいです：

```bash
watch 'kubectl get all -o wide -n dev'
```

適用：

```bash
k apply -f ./manifests/web-deployment.yaml
```

適用後の状態：

```
NAME                                   READY   UP-TO-DATE   AVAILABLE   AGE    CONTAINERS   IMAGES                  SELECTOR
deployment.apps/web-deployment   3/3     3            3           115s   web    nginx:1.27-alpine3.19   app=web

NAME                                              DESIRED   CURRENT   READY   AGE    CONTAINERS   IMAGES                  SELECTOR
replicaset.apps/web-deployment-5cd4b9b767   0         0         0       115s   web    nginx:latest            ...
replicaset.apps/web-deployment-76c5c6c447   3         3         3       10s    web    nginx:1.27-alpine3.19   ...
```

イメージを切り替える場合は、ReplicaSet ごと作成されてレプリカ数を調整することでローリングアップデートを実現します。

### ロールバック

Deployment はデプロイ履歴を保持しているため、過去のバージョンに簡単に切り戻すことができます。

#### デプロイ履歴を確認する

まず、現在のデプロイ履歴を確認します：

```bash
k -n dev rollout history deployment/web-deployment
```

**出力例:**

```
deployment.apps/web-deployment
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

REVISION 番号が大きいほど新しいデプロイです。各リビジョンの詳細を見るには：

```bash
k -n dev rollout history deployment/web-deployment --revision=1
```

**出力例:**

```
deployment.apps/web-deployment with revision #1
Pod Template:
  Labels:       app=web
                pod-template-hash=5cd4b9b767
  Containers:
   web:
    Image:      nginx:latest
    ...
```

これにより、各リビジョンでどのイメージが使われていたかを確認できます。

#### 1つ前のバージョンに戻す

```bash
k -n dev rollout undo deployment/web-deployment
```

**出力例:**

```
deployment.apps/web-deployment rolled back
```

ロールバック後の状態を確認します：

```bash
k -n dev get deployment web-deployment -o wide
```

```
NAME             READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS   IMAGES         SELECTOR
web-deployment   3/3     3            3           5m54s   web          nginx:latest   app=web
```

イメージが `nginx:latest` に戻っていることを確認できます。

#### 特定のリビジョンに戻す

特定のリビジョンを指定して戻すこともできます：

```bash
k -n dev rollout undo deployment/web-deployment --to-revision=1
```

問題のある Pod をデプロイしてしまっても、履歴を確認して適切なバージョンにすぐに切り戻すことができます。

### Deployment の削除

次のセクションに進む前に、一度 Deployment を削除してクリーンな状態にします：

```bash
k delete -f ./manifests/web-deployment.yaml
```

---

## 更新戦略を理解する

ローリングアップデートの挙動は `maxSurge` と `maxUnavailable` の設定によって変わります。実際に設定を変えて動作を確認してみましょう。

### Deployment を再作成

まずクリーンな状態から Deployment を作成します：

```bash
k apply -f ./manifests/web-deployment.yaml
```

Deployment が正常に展開されたことを確認します：

```bash
k -n dev rollout status deployment/web-deployment
```

**期待される出力:**

```
deployment "web-deployment" successfully rolled out
```

このメッセージが表示されれば、全ての Pod が正常に起動しています。

### 設定の意味をおさらい

| 設定 | 意味 |
|------|------|
| `maxSurge` | 更新中に replicas 数を超えて**追加で作成できる** Pod の最大数 |
| `maxUnavailable` | 更新中に**ダウンしていてよい** Pod の最大数 |

### maxSurge: 1, maxUnavailable: 1 の場合（デフォルト）

replicas が 3 の場合：
- 最大 4 つの Pod が同時に存在できる（3 + maxSurge: 1）
- 最低 2 つの Pod は常に稼働している（3 - maxUnavailable: 1）

新しい Pod を 1 つ作成しながら、古い Pod を 1 つ削除する、という流れで更新されます。

### maxSurge: 0 の場合を確認する

`maxSurge: 0` に設定すると、**余分な Pod を作成せず**に更新が行われます。

まず strategy を `maxSurge: 0, maxUnavailable: 1` に変更します：

```bash
k -n dev patch deployment web-deployment -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":0,"maxUnavailable":1}}}}'
```

変更が適用されたことを確認します：

```bash
k -n dev get deployment web-deployment -o jsonpath='{.spec.strategy.rollingUpdate}' | jq
```

**期待される出力:**

```json
{
  "maxSurge": 0,
  "maxUnavailable": 1
}
```

watch で監視しながらイメージを更新します：

```bash
# 別ターミナルで監視
watch 'kubectl -n dev get pods -o wide'
```

```bash
k -n dev set image deployment/web-deployment web=nginx:1.27-alpine
```

**観察される動作:**

```
NAME                              READY   STATUS        RESTARTS   AGE
web-deployment-5cd4b9b767-abc12   1/1     Terminating   0          5m    # まず古いPodが削除される
web-deployment-5cd4b9b767-def34   1/1     Running       0          5m
web-deployment-5cd4b9b767-ghi56   1/1     Running       0          5m
```

```
NAME                              READY   STATUS              RESTARTS   AGE
web-deployment-5cd4b9b767-def34   1/1     Running             0          5m
web-deployment-5cd4b9b767-ghi56   1/1     Running             0          5m
web-deployment-76c5c6c447-xyz99   0/1     ContainerCreating   0          2s    # 削除後に新しいPodが作成される
```

> **Note**: 一時的に4つの Pod が表示されることがありますが、`Terminating`（終了中）や `ContainerCreating`（起動中）の Pod はリクエストを受け付けません。実際に稼働している Pod は `READY 1/1` かつ `Running` のものだけです。

`maxSurge: 0` の場合、**先に古い Pod が削除されてから新しい Pod が作成される**ため、一時的に利用可能な Pod 数が減ります（3 → 2 → 3 の繰り返し）。

### maxSurge: 0, maxUnavailable: 0 の場合（デッドロック）

両方を 0 に設定するとどうなるでしょうか？

```bash
k -n dev patch deployment web-deployment -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":0,"maxUnavailable":0}}}}'
```

**結果:**

```
The Deployment "web-deployment" is invalid: spec.strategy.rollingUpdate.maxUnavailable: Invalid value: 0: may not be 0 when `maxSurge` is 0
```

Kubernetes はこの設定を**拒否**し、変更は適用されません。設定が変わっていないことを確認できます：

```bash
k -n dev get deployment web-deployment -o jsonpath='{.spec.strategy.rollingUpdate}' | jq
```

```json
{
  "maxSurge": 0,
  "maxUnavailable": 1
}
```

拒否される理由は：

- `maxSurge: 0` → 新しい Pod を追加で作成できない
- `maxUnavailable: 0` → 古い Pod を削除できない（常に全ての Pod が稼働している必要がある）

この状態では新しい Pod を作る余地がなく、古い Pod も削除できないため、更新が不可能（デッドロック）になります。Kubernetes はこのような無効な設定を検知してエラーを返します。

### 設定を元に戻す

確認が終わったら設定を元に戻しておきます：

```bash
k -n dev patch deployment web-deployment -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":1,"maxUnavailable":1}}}}'
```

### まとめ：maxSurge と maxUnavailable の関係

| maxSurge | maxUnavailable | 動作 |
|----------|----------------|------|
| 1 | 1 | 1つ追加して1つ削除（バランス型） |
| 0 | 1 | 先に1つ削除してから1つ追加（Pod数を超えない） |
| 1 | 0 | 先に1つ追加してから1つ削除（常に全Pod稼働） |
| 0 | 0 | **無効**（デッドロックするため拒否される） |

用途に応じて：
- **リソースに余裕がない場合**: `maxSurge: 0` で Pod 数を超えないようにする
- **ダウンタイムを許容できない場合**: `maxUnavailable: 0` で常に全 Pod を稼働させる

---

## クリーンアップ

Deployment によって作成されたリソースは Deployment を削除するだけで全て消えます。

```bash
k delete -f ./manifests/web-deployment.yaml
```

クラスターごと削除する場合:

```bash
kind delete cluster
```

---

## まとめ

本ガイドで学んだことを振り返ります。

### ReplicaSet だけでは解決できない問題

- template を変更しても既存の Pod は更新されない
- ローリングアップデートを行うには、新旧の ReplicaSet を手動で調整する必要がある
- ロールバックも同様に手作業が必要

### Deployment が提供する価値

- **宣言的なローリングアップデート**: manifest を変更して `apply` するだけで、段階的な Pod の入れ替えが自動で行われる
- **ワンコマンドでのロールバック**: `rollout undo` で即座に前の状態に復元できる
- **更新戦略の柔軟な制御**: `maxSurge` と `maxUnavailable` で、リソース制約やダウンタイム許容度に応じた更新方法を選択できる

### 実運用での意義

障害発生時に素早く復旧できることは、サービスの信頼性に直結します。Deployment によるロールバックの容易さは、DORA メトリクス（DevOps Research and Assessment）の「変更障害率」や「サービス復旧時間」の改善に貢献します。

## 参考資料

- [Kubernetes公式ドキュメント - Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubectl コマンドリファレンス](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands)
