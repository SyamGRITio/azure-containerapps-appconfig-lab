# インフラ

このPoCのAzureリソースとGitHub ActionsのRepository Variablesは、`infra/` のTerraformで管理しています。アプリのイメージ更新はTerraformから切り離し、[デプロイ用ワークフロー](../.github/workflows/app-deploy.yaml)に任せます。

## 何をどこで管理するか

| 担当 | 管理するもの |
| --- | --- |
| Terraform | ACR、App Configuration、Key Vault、ACA、マネージドID、権限、GitHub Actionsの変数とOIDC連携 |
| GitHub Actions | Goアプリのビルド、ACRへのpush、`app:imageTag` の更新、ACAの新しいイメージへの更新 |
| Terraformの外 | Key Vault Secretの実値 |

ACAの実行用ID（`id-aca-runtime`）はACRからのpull、App ConfigurationとKey Vaultの読み取りに使います。デプロイ用ID（`id-github-app-deploy`）はGitHub ActionsがOIDCでAzureへログインするときに使います。

## 初回構築の順番

最初はACRにアプリのイメージがないため、ACAを含めて一度に `terraform apply` することはできません。この順番で構築しました。

1. TerraformでResource Group、ACR、App Configuration、Key Vault、マネージドID、Container Apps Environmentと必要な権限を部分適用する。
2. Goアプリのイメージをビルドし、Gitの短いコミットSHAをタグにしてACRへpushする。
3. TerraformでApp ConfigurationのキーとKey VaultのSecretを部分適用する。ACAはまだ作らない。
4. App Configurationの `app:imageTag` にpushしたタグを設定し、Key Vault Secretに実値を設定する。
5. `terraform apply` で残りを作成する。

ACAは実行用IDにACRの読み取り権限を付与してから作成します。`azurerm_container_app.main` の `depends_on` は、この順番をTerraformに伝えるためのものです。

## デプロイ後の確認

`app/**` を `main` にpushすると、[アプリのワークフロー](../.github/workflows/app-deploy.yaml)がイメージのpush、App Configurationのタグ更新、ACA更新を順に実行します。手動実行もできます。

PowerShellで次の値を比較できます。

```powershell
az appconfig kv show `
  --endpoint https://appcs-aca-appconfig-poc.azconfig.io `
  --key app:imageTag --label dev --auth-mode login `
  --query value -o tsv

az containerapp show `
  --name ca-appconfig-poc `
  --resource-group rg-aca-appconfig-poc `
  --query "{latest:properties.latestRevisionName,ready:properties.latestReadyRevisionName,image:properties.template.containers[0].image,host:properties.configuration.ingress.fqdn}" `
  -o json

terraform plan
```

App Configurationのタグ、ACAのイメージタグ、ブラウザーに表示される `App Version` が一致し、`terraform plan` が `No changes` なら、今回の責務分担を確認できます。

## Terraformとデプロイが衝突しないために

- `app:imageTag` はTerraformがキーを作成し、値はデプロイ時に更新します。Terraformは値の変更を `ignore_changes` します。
- Key Vault SecretもTerraformがリソースを作成し、実値はTerraform外で設定します。実値の変更は `ignore_changes` します。
- GitHub Actionsが使うRepository Variablesは [`github.tf`](github.tf) で管理します。認証用のクライアントIDもSecretではなく変数です。
- Terraform stateは現在ローカル保存です。`terraform.tfstate` はGitの管理対象から除外しています。

## やってみて詰まったところ

- **権限付与の繰り返し** — 同じ形のRole Assignmentを何度も書くのはつらいので、ロール名と対象スコープを `locals` にまとめ、`for_each` で作る形にしました。
- **ACAを作る順番** — 実行用IDへの権限付与とACAを一緒に作ったとき、ACRからのpullが `UNAUTHORIZED` になりました。権限付与を先に終えるよう `depends_on` を追加し、再作成して動作を確認しました。
- **`terraform destroy` で止まる** — ACAとContainer Apps Environmentの削除中にTerraformがエラーになっても、Azure側では対象が `ResourceNotFound` になっていました。削除処理とproviderの完了確認のタイミングがずれた可能性を疑っていますが、原因はまだ特定できていません。Azure側で消えたことを確認してから `terraform destroy` を再実行すると、stateも追従しました。

作成できたところで終わらせず、削除・再作成、画面表示、App Configurationの値、`terraform plan` が `No changes` になるところまで確認しました。
