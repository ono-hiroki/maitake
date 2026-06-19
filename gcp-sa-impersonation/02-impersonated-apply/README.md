# 02-impersonated-apply — SA を impersonate して apply する

01 で土台ができている前提。ここでは **HCL を変えず、環境変数だけで** impersonate に切り替わる
ことを、`whoami_email` 出力で目で見て確認する。

## キモ

`provider "google"` ブロックには impersonate を**書いていない**。切替はこの 1 行だけ:

```bash
export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT=lab-tf-runner@my-sandbox.iam.gserviceaccount.com
```

この変数を provider も GCS backend も尊重するので、変数 ON/OFF で実行 ID が丸ごと切り替わる。

## ハンズオン: before / after を比べる

### A) 変数なし（＝今までどおり個人 ADC）

```bash
cd gcp-sa-impersonation/02-impersonated-apply
terraform init
unset GOOGLE_IMPERSONATE_SERVICE_ACCOUNT   # 念のため
terraform apply
# → Outputs: whoami_email = "you@example.com"   ← あなた個人
```

### B) 変数あり（＝SA を impersonate）

```bash
export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT=lab-tf-runner@my-sandbox.iam.gserviceaccount.com
terraform apply
# → Outputs: whoami_email = "lab-tf-runner@my-sandbox.iam.gserviceaccount.com"  ← SA！
```

`whoami_email` が **個人 → SA** に変わっていれば成功。これが「apply 時に個人権限を使わず、
SA をなりすまして実行する」状態。完了定義そのもの。

> `terraform plan` でも `whoami_email` は確認できる（data source は plan 時に解決される）。
> apply せず確認だけしたいなら `terraform plan` でOK。

## 別解: 方法②（ADC に焼き込む）で試す

上の A/B は **方法③**（環境変数で provider に impersonate を指示）。
同じコード・同じ `01` の土台のまま、**方法②**（ADC ファイル自体に impersonate を焼き込む）でも
全く同じ結果になることを試せる。`02` のコードは「ADC を読むだけ」なので**無改造**でよい。

```bash
# 1) 方法③の環境変数は消しておく（②と混ざらないように）
unset GOOGLE_IMPERSONATE_SERVICE_ACCOUNT

# 2) ADC 自体を「impersonate するADC」として作り直す（←これが方法②）
gcloud auth application-default login \
  --impersonate-service-account=lab-tf-runner@my-sandbox.iam.gserviceaccount.com

# 3) 環境変数なしでそのまま apply → whoami_email は SA になる
terraform apply
# → Outputs: whoami_email = "lab-tf-runner@my-sandbox.iam.gserviceaccount.com"
```

### ③（環境変数）との違い

| | ②ADC焼き込み（この節） | ③環境変数（A/B の B） |
|---|---|---|
| impersonate先の保持場所 | ADC ファイルに焼き込む | 環境変数（ADC は個人のまま） |
| 切替方法 | SA を変えるたび `gcloud auth application-default login --impersonate-...` を再実行 | 環境変数の値を変えるだけ |
| multi-env(dev/prd) | 都度ログインし直しで手間 | 変数差し替えで楽 |

### ② を元に戻す（個人 ADC に復帰）

```bash
# impersonate を焼いた ADC を、素の個人 ADC に作り直す
gcloud auth application-default login
```

> **ハマりどころ: `unset` では戻らない。**
> ②は ADC ファイル自体に impersonate を焼き込むので、`unset GOOGLE_IMPERSONATE_SERVICE_ACCOUNT`
> （= ③ の戻し方）をしても SA のまま。terraform は ADC を読むため。**②の戻しは再ログインが必須**。
>
> ```bash
> # 今 impersonate しているのが ② (ADC) か確認:
> grep -i impersonat ~/.config/gcloud/application_default_credentials.json
> #   service_account_impersonation_url が出る → ②が効いている = 再ログインで戻す
> ```
>
> | 効かせた方法 | 戻し方 |
> |---|---|
> | ③ 環境変数 | `unset GOOGLE_IMPERSONATE_SERVICE_ACCOUNT` |
> | ② ADC焼き込み | `gcloud auth application-default login`（フラグなし再ログイン） |

### 参考: 方法①（gcloud CLI）は「gcloud コマンドを SA で実行する」

方法① (`--impersonate-service-account` フラグ / `gcloud config set auth/impersonate_service_account`)
は **`gcloud` コマンドを SA の権限で走らせる**もの。`list` / `describe` などの読み取りも、
`create` 等の書き込みも、SA がそのロールを持っていれば動く（無ければ `PERMISSION_DENIED`）。

```bash
# 1コマンドだけ SA で実行（SA は 01 で storage.admin を持つので list できる）
gcloud storage buckets list \
  --impersonate-service-account=lab-tf-runner@my-sandbox.iam.gserviceaccount.com

# セッション中ずっと SA で実行したいとき
gcloud config set auth/impersonate_service_account lab-tf-runner@my-sandbox.iam.gserviceaccount.com
gcloud storage buckets list          # ← これも SA 権限で動く
gcloud config unset auth/impersonate_service_account   # 解除（個人に戻す）
```

ただし**① は terraform apply / plan には効かない**（terraform は gcloud の設定を見ず、
ADC・環境変数・provider 設定だけを見るため）。用途の整理:

| ツール | ①が効く？ |
|---|---|
| `gcloud` コマンド全般（list / describe / create …） | ⭕ |
| `terraform apply` / `plan` | ❌（③ or ② を使う） |

このラボでも①は「借用可否の確認」(`gcloud auth print-access-token
--impersonate-service-account=...`, → `01` の next_step) に使っている。これも①の一種で、
list 等の前に「そもそもこの SA を借りられるか（tokenCreator があるか）」を確かめる使い方。

## うまくいかない時

| 症状 | 原因 / 対処 |
|---|---|
| `PERMISSION_DENIED` on `iamcredentials.generateAccessToken` | tokenCreator 付与が未反映 or 付け忘れ。01 を見直し数分待つ |
| `whoami_email` が個人のまま | `export` が効いていない / 別シェル。`echo $GOOGLE_IMPERSONATE_SERVICE_ACCOUNT` で確認 |
| `google_client_openid_userinfo` が scope エラー | ADC 再作成: `gcloud auth application-default login`。代替確認は監査ログでバケット作成者を見る |

## 後片付け

```bash
# まだ impersonate のまま destroy できる（SA に storage.admin があるため）
terraform destroy
# その後 ../01-bootstrap-sa で destroy（個人 ADC に戻してから）
unset GOOGLE_IMPERSONATE_SERVICE_ACCOUNT
```
