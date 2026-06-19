# gcp-sa-impersonation — terraform を Service Account インパーソネートで実行する

個人の権限（ADC）で `terraform apply` している状態から、**terraform 実行用 SA を
impersonate（なりすまし）して apply する**状態へ移行する流れを、最小構成で体感する学習用ラボ。

> 背景: 「apply 時に個人の強い権限を使わない（権限を SA に集約する）」へ移行する前の素振り。
> 実務では Terragrunt などで provider/backend を生成してこの切替を行うことが多いが、
> ここでは本質だけを残すため **素の Terraform + 環境変数 1 つ**でなぞる。

## このラボで分かること

1. **そもそも何が嬉しいのか**: 個人に強権限を持たせず、権限を SA に集約できる
2. **トークンの仕組み**: `roles/iam.serviceAccountTokenCreator` で短命トークンを発行してもらう
3. **卵が先か鶏が先か**: SA を作る最初の apply だけは個人 ADC で行う（ブートストラップ）
4. **切替方法**: 環境変数 `GOOGLE_IMPERSONATE_SERVICE_ACCOUNT` で HCL 無改造で impersonate 化

| パート | 内容 | 実行する権限 |
|---|---|---|
| [01-bootstrap-sa](01-bootstrap-sa) | tf-runner SA を作る + 自分に tokenCreator を付与 | **個人 ADC**（ブートストラップ） |
| [02-impersonated-apply](02-impersonated-apply) | SA を impersonate してバケットを作る + whoami で確認 | **tf-runner SA**（なりすまし） |

## 前提

- GCP project: `my-sandbox`（**自分のプロジェクト ID に置き換える**） / region: `asia-northeast1`
- 個人アカウント: `you@example.com`（sandbox の owner 相当を想定）
- ADC を作成済みであること: `gcloud auth application-default login`

> `variables.tf` の `project_id` / `token_creator_member` の default を自分の値に変えるか、
> `terraform apply -var=...` または `terraform.tfvars` で上書きする。
> 以降このドキュメントでは `my-sandbox` / `you@example.com` で表記する。

## 全体の流れ（3ステップ）

```
STEP 1) 個人 ADC のまま 01 を apply
        └─ lab-tf-runner SA 作成 + SAに storage.admin + 自分に tokenCreator
STEP 2) impersonate を有効化（環境変数をセット）
        export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT=lab-tf-runner@my-sandbox.iam.gserviceaccount.com
STEP 3) 02 を apply → 実際の操作は SA の権限で走る（個人権限は使われない）
        └─ whoami 出力が SA のメールになることで「なりすませている」を確認
```

なぜ 01 は個人 ADC なのか:
SA とその tokenCreator 付与が**まだ存在しない**段階で impersonate しようとしても、
「借りる相手がいない / 借りる鍵がない」ので失敗する。だから**SA を生む最初の一回だけ**は
個人権限で行う。これがブートストラップ（卵が先か鶏が先か）問題。

## 進め方

各ディレクトリの README に手順がある。まず `01` → 次に `02`。
後片付けは逆順（`02` destroy → `01` destroy）。

## 実務（GCS backend）に持っていくときの注意

本ラボはローカル state なので backend は対象外。実運用（GCS backend）では
provider だけでなく **backend にも** impersonate 設定が要る。環境変数
`GOOGLE_IMPERSONATE_SERVICE_ACCOUNT` は provider と GCS backend の**両方が尊重する**ため、
変数 1 つで両方まとめて切り替えられる。
