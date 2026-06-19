# 01-bootstrap-sa — 個人 ADC で terraform 実行用 SA を作る

impersonate の土台を 3 点セットで用意する。**このディレクトリだけは個人 ADC で apply する**
（ブートストラップ。理由は親 [README](../README.md) の「卵が先か鶏が先か」を参照）。

## 作るもの

| # | リソース | 意味 |
|---|---|---|
| ① | `google_service_account.tf_runner` | なりすます相手（`lab-tf-runner@my-sandbox.iam.gserviceaccount.com`） |
| ② | `google_project_iam_member.tf_runner_roles` | SA に `roles/storage.admin`（02 でバケットを作るため） |
| ③ | `google_service_account_iam_member.token_creator` | 自分に `roles/iam.serviceAccountTokenCreator`（借りる鍵） |

## 前提

```bash
# 個人 ADC を用意（まだなら）
gcloud auth application-default login
gcloud config set project my-sandbox
```

> `project_id` / `token_creator_member` は `variables.tf` の default を自分の値に
> 置き換えるか、`-var=...` / `terraform.tfvars` で上書きする。

## 手順

```bash
cd gcp-sa-impersonation/01-bootstrap-sa
terraform init
terraform apply
```

apply 後、出力 `sa_email` と `next_step` が表示される。`next_step` のコマンドをそのまま実行して
02 へ進む。

## 確認

```bash
# SA ができたか
gcloud iam service-accounts describe lab-tf-runner@my-sandbox.iam.gserviceaccount.com

# 自分が impersonate できるか（成功すればトークン文字列が返る）
gcloud auth print-access-token \
  --impersonate-service-account=lab-tf-runner@my-sandbox.iam.gserviceaccount.com
```

> `iam.serviceAccountTokenCreator` の付与は反映に数十秒〜数分かかることがある。
> 上の print-access-token が `PERMISSION_DENIED` なら少し待って再実行。

## 後片付け

02 を destroy した後に、ここで `terraform destroy`。
