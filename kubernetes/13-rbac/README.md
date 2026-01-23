# RBACでアクセス制御する

---

# 概念編

## RBAC とは

RBAC は **誰が（Subject）何に対して（Resource）何をできるか（Verb）を制御する** Kubernetes の認可機能です。

```
┌─────────────────────────────────────────────────────────────────┐
│                           RBAC の構成要素                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Subject（誰が）          Role（何ができるか）                    │
│   ┌─────────────────┐     ┌─────────────────────────────┐      │
│   │ ServiceAccount  │     │ resources: [pods, services] │      │
│   │ User            │     │ verbs: [get, list, create]  │      │
│   │ Group           │     └─────────────────────────────┘      │
│   └─────────────────┘                   │                       │
│            │                            │                       │
│            │         RoleBinding        │                       │
│            │    ┌─────────────────┐     │                       │
│            └───▶│   紐付け        │◀────┘                       │
│                 └─────────────────┘                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 4 つの主要リソース

| リソース | スコープ | 用途 |
|---------|---------|------|
| **Role** | Namespace | 特定の Namespace 内の権限を定義 |
| **ClusterRole** | Cluster 全体 | クラスタ全体の権限を定義 |
| **RoleBinding** | Namespace | Role/ClusterRole を Subject に紐付け |
| **ClusterRoleBinding** | Cluster 全体 | ClusterRole を Subject に紐付け |

```
                  ┌─────────────────────────────────────┐
                  │           ClusterRole               │
                  │      （クラスタ全体で使える権限）      │
                  └─────────────────────────────────────┘
                           │                 │
          ClusterRoleBinding               RoleBinding
          （クラスタ全体に適用）            （特定 Namespace に適用）
                           │                 │
                           ▼                 ▼
                  ┌─────────────┐    ┌─────────────┐
                  │ 全 Namespace │    │ Namespace A │
                  └─────────────┘    └─────────────┘

                  ┌─────────────────────────────────────┐
                  │              Role                   │
                  │     （特定 Namespace 内の権限）        │
                  └─────────────────────────────────────┘
                                     │
                                RoleBinding
                                     │
                                     ▼
                            ┌─────────────┐
                            │ Namespace A │
                            └─────────────┘
```

## Subject（誰が）

| 種類 | 説明 | 用途 |
|------|------|------|
| **ServiceAccount** | Pod が使用するアカウント | アプリケーションの権限管理 |
| **User** | 人間のユーザー | kubectl を使う開発者 |
| **Group** | ユーザーのグループ | チーム単位の権限管理 |

実務では **ServiceAccount** を最もよく使います。Pod に特定の権限を与えるためです。

## Verb（何をできるか）

| Verb | 説明 | 対応する HTTP メソッド |
|------|------|----------------------|
| `get` | 単一リソースの取得 | GET (単一) |
| `list` | リソース一覧の取得 | GET (一覧) |
| `watch` | リソースの変更監視 | GET (watch) |
| `create` | リソースの作成 | POST |
| `update` | リソースの更新 | PUT |
| `patch` | リソースの部分更新 | PATCH |
| `delete` | リソースの削除 | DELETE |
| `deletecollection` | 複数リソースの一括削除 | DELETE (複数) |

よく使う組み合わせ：

| パターン | Verbs |
|---------|-------|
| 読み取り専用 | `get`, `list`, `watch` |
| 読み書き | `get`, `list`, `watch`, `create`, `update`, `patch`, `delete` |
| 完全な権限 | `*`（すべて） |

## Role の例

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: default
rules:
  - apiGroups: [""]           # コア API（Pod, Service 等）
    resources: ["pods"]       # 対象リソース
    verbs: ["get", "list"]    # 許可する操作
```

### apiGroups について

| apiGroups | 対象リソース |
|-----------|-------------|
| `""` (空文字) | Pod, Service, ConfigMap, Secret 等（コア API） |
| `apps` | Deployment, StatefulSet, DaemonSet, ReplicaSet |
| `batch` | Job, CronJob |
| `networking.k8s.io` | Ingress, NetworkPolicy |
| `rbac.authorization.k8s.io` | Role, RoleBinding 等 |

## ServiceAccount のデフォルト動作

すべての Pod は ServiceAccount で動作します。

```yaml
# 明示的に指定しない場合
spec:
  serviceAccountName: default  # ← 暗黙的に "default" が使われる
```

`default` ServiceAccount には最小限の権限しかありません。

## 最小権限の原則

**必要な権限だけを付与する** のがセキュリティの基本です。

```
❌ 悪い例：
   ClusterRole に * (すべて) の権限を与える

✅ 良い例：
   Role に特定の Namespace 内の pods の get, list だけを与える
```

## EKS での RBAC

EKS では **IAM ユーザー/ロール** と **Kubernetes RBAC** が連携します。

```
AWS IAM                         Kubernetes RBAC
┌──────────────┐                ┌──────────────────┐
│ IAM User/Role │──── 認証 ────▶│ Kubernetes User   │
└──────────────┘                └──────────────────┘
                                         │
                                    RoleBinding
                                         │
                                         ▼
                                ┌──────────────────┐
                                │ Role/ClusterRole │
                                └──────────────────┘
```

EKS に進む前に、この基本を理解しておくと IAM 連携がスムーズです。

## 参考リンク

- [Using RBAC Authorization | Kubernetes](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Configure Service Accounts for Pods | Kubernetes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)

---

# ハンズオン編

ここからは実際に手を動かして RBAC の動作を確認します。

## やること

| Step | 内容 |
|------|------|
| Step 1 | ServiceAccount を作成する |
| Step 2 | Role を作成して権限を定義する |
| Step 3 | RoleBinding で紐付ける |
| Step 4 | 権限をテストする |
| Step 5 | ClusterRole / ClusterRoleBinding を試す |
| Step 6 | クリーンアップ |

## シナリオ

「Pod の情報を読み取れるが、作成・削除はできない」権限を持つ ServiceAccount を作成します。

## 事前準備

```bash
# kind クラスタが起動していることを確認
k cluster-info
```

---

## Step 1: ServiceAccount を作成する

### YAML で作成

`manifests/serviceaccount.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pod-reader-sa
  namespace: default
```

```bash
k apply -f manifests/serviceaccount.yaml
```

### 確認

```bash
k get serviceaccount
```

```
NAME            SECRETS   AGE
default         0         10d
pod-reader-sa   0         5s    ← 作成された
```

---

## Step 2: Role を作成する

「Pod を get, list できる」権限を定義します。

`manifests/role.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: default
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
```

```bash
k apply -f manifests/role.yaml
```

### 確認

```bash
k get role
```

```
NAME         CREATED AT
pod-reader   2024-01-15T10:00:00Z
```

```bash
k describe role pod-reader
```

```
Name:         pod-reader
Labels:       <none>
Annotations:  <none>
PolicyRule:
  Resources  Non-Resource URLs  Resource Names  Verbs
  ---------  -----------------  --------------  -----
  pods       []                 []              [get list]
```

---

## Step 3: RoleBinding を作成する

ServiceAccount と Role を紐付けます。

`manifests/rolebinding.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: default
subjects:
  - kind: ServiceAccount
    name: pod-reader-sa
    namespace: default
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

```bash
k apply -f manifests/rolebinding.yaml
```

### 確認

```bash
k get rolebinding
```

```
NAME                 ROLE              AGE
pod-reader-binding   Role/pod-reader   5s
```

```bash
k describe rolebinding pod-reader-binding
```

```
Name:         pod-reader-binding
Labels:       <none>
Annotations:  <none>
Role:
  Kind:  Role
  Name:  pod-reader
Subjects:
  Kind            Name           Namespace
  ----            ----           ---------
  ServiceAccount  pod-reader-sa  default
```

---

## Step 4: 権限をテストする

### テスト用の Pod を作成

まず、作成した ServiceAccount を使う Pod を作成します。

`manifests/test-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: rbac-test
  namespace: default
spec:
  serviceAccountName: pod-reader-sa
  containers:
    - name: kubectl
      image: bitnami/kubectl:latest
      command: ["sleep", "3600"]
```

```bash
k apply -f manifests/test-pod.yaml
```

### 確認用の Pod も作成

権限テストのために、別の Pod も作成しておきます。

```bash
k run nginx --image=nginx
```

### 権限をテストする

Pod の中に入って、kubectl コマンドを実行します。

```bash
k exec -it rbac-test -- sh
```

#### 許可されている操作

```sh
# Pod 一覧を取得（get, list 権限あり）
$ kubectl get pods
NAME        READY   STATUS    RESTARTS   AGE
nginx       1/1     Running   0          30s
rbac-test   1/1     Running   0          1m
```

成功します。

#### 許可されていない操作

```sh
# Pod を削除しようとする（delete 権限なし）
$ kubectl delete pod nginx
Error from server (Forbidden): pods "nginx" is forbidden: User "system:serviceaccount:default:pod-reader-sa" cannot delete resource "pods" in API group "" in the namespace "default"
```

```sh
# Deployment を取得しようとする（deployments の権限なし）
$ kubectl get deployments
Error from server (Forbidden): deployments.apps is forbidden: User "system:serviceaccount:default:pod-reader-sa" cannot list resource "deployments" in API group "apps" in the namespace "default"
```

```sh
# 別の Namespace の Pod を取得しようとする（default 以外の権限なし）
$ kubectl get pods -n kube-system
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:default:pod-reader-sa" cannot list resource "pods" in API group "" in the namespace "kube-system"
```

すべて `Forbidden` エラーになります。RBAC が正しく機能しています。

```sh
$ exit
```

---

## Step 5: ClusterRole / ClusterRoleBinding を試す

クラスタ全体で Pod を読み取れる権限を付与します。

### ClusterRole を作成

`manifests/clusterrole.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-pod-reader
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
```

### ClusterRoleBinding を作成

`manifests/clusterrolebinding.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-pod-reader-binding
subjects:
  - kind: ServiceAccount
    name: pod-reader-sa
    namespace: default
roleRef:
  kind: ClusterRole
  name: cluster-pod-reader
  apiGroup: rbac.authorization.k8s.io
```

```bash
k apply -f manifests/clusterrole.yaml
k apply -f manifests/clusterrolebinding.yaml
```

### 権限をテストする

```bash
k exec -it rbac-test -- sh
```

```sh
# 今度は kube-system の Pod も取得できる
$ kubectl get pods -n kube-system
NAME                                         READY   STATUS    RESTARTS   AGE
coredns-xxxx                                 1/1     Running   0          10d
etcd-kind-control-plane                      1/1     Running   0          10d
...
```

ClusterRoleBinding により、すべての Namespace の Pod を取得できるようになりました。

```sh
$ exit
```

---

## Step 6: クリーンアップ

```bash
# テスト用リソースを削除
k delete pod rbac-test nginx

# RBAC リソースを削除
k delete -f manifests/
```

---

## よく使うコマンドまとめ

```bash
# ServiceAccount
k get serviceaccount
k create serviceaccount <name>

# Role / ClusterRole
k get role
k get clusterrole
k describe role <name>

# RoleBinding / ClusterRoleBinding
k get rolebinding
k get clusterrolebinding
k describe rolebinding <name>

# 権限の確認（自分の権限）
k auth can-i get pods
k auth can-i delete pods
k auth can-i --list

# 権限の確認（特定の ServiceAccount）
k auth can-i get pods --as=system:serviceaccount:default:pod-reader-sa
k auth can-i delete pods --as=system:serviceaccount:default:pod-reader-sa
```

---

## 実務でよく使うパターン

### パターン 1: アプリが ConfigMap/Secret を読み取る

```yaml
rules:
  - apiGroups: [""]
    resources: ["configmaps", "secrets"]
    verbs: ["get", "list", "watch"]
```

### パターン 2: CI/CD が Deployment を更新する

```yaml
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "update", "patch"]
```

### パターン 3: 監視ツールがクラスタ全体を読み取る

```yaml
# ClusterRole として定義
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "endpoints"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "watch"]
```

---

## まとめ

| 要素 | 役割 |
|------|------|
| ServiceAccount | Pod のアイデンティティ |
| Role | Namespace 内の権限定義 |
| ClusterRole | クラスタ全体の権限定義 |
| RoleBinding | Role/ClusterRole と Subject の紐付け（Namespace スコープ） |
| ClusterRoleBinding | ClusterRole と Subject の紐付け（クラスタスコープ） |

**ポイント:**
- 最小権限の原則を守る
- まず Role で Namespace 単位の権限を検討
- クラスタ全体が必要な場合のみ ClusterRole を使う
- EKS では IAM との連携を意識する
