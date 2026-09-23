# Bicep版

Terraform版と同じ名前・設定のAzure環境をBicepで作り、アプリ更新をIaCから分離できるか確認するためのコードです。

## ファイルの役割

| ファイル | 作るもの |
| --- | --- |
| `main.bicep` | Resource Groupと`foundation.bicep`の呼び出し |
| `foundation.bicep` | ACR、App Configuration、Key Vault、2つのUAMI、OIDC、Container Apps Environment、RBAC |
| `settings.bicep` | App Configurationの3キーとKey Vault Secretの初期値 |
| `app.bicep` | App Configurationの現在のイメージタグを参照するContainer App |

## Terraform版と揃えた内容

- Resource Group、ACR、App Configuration、Key Vault、Container Apps Environment、Container App、2つのUAMIの名前
- SKU、リージョン、公開アクセス、タグ、Key Vaultの保持期間
- App Configurationのキー、ラベル、初期値とKey Vault参照
- Container Appのイメージ、環境変数、Ingress、Probe、スケール設定
- Runtime UAMI、Deploy UAMI、検証を実行するユーザーのRBAC
- GitHub `main` ブランチを許可するFederated Credential

同じSubscriptionへTerraform版とBicep版を同時に作る構成ではありません。片方を削除してから、もう片方を検証します。

## 初回構築の順番

1. `main.bicep`でResource Groupと基盤を作る。
2. ACRへ最初のアプリイメージをpushする。
3. `settings.bicep`でApp ConfigurationのキーとKey Vault Secretを作る。
4. `app:imageTag`とSecretを検証用の値へ更新する。
5. `app.bicep`でContainer Appを作る。

`settings.bicep`は初回値を入れるためのファイルです。BicepにはTerraformの`ignore_changes`に相当する指定がないため、CDがタグを更新した後に再実行すると`app:imageTag`を初期値へ戻します。

## 管理の境界

- Bicep: Azureの基盤、権限、App Configurationキーの置き場所、ACAの構成
- GitHub Actions: イメージのbuild・push、`app:imageTag`の更新、ACAのイメージ更新
- GitHub: Repository Variables
- Bicepの外: Key Vault Secretの実値

GitHubのRepository VariablesはAzureリソースではないため、Bicepでは作成しません。Bicep版で検証するときは、作成したUAMIのClient IDや各リソース名をGitHub側へ設定します。

## 再デプロイの確認

CDと同じ手順でApp ConfigurationとACAを新しいタグへ更新した後は、`settings.bicep`を除き、`main.bicep`と`app.bicep`を再実行します。タグが巻き戻らず、不要なRevisionも作られないことを確認します。

`az deployment group what-if`では、App Configurationのキーを参照する`reference()`が値まで解決されません。実際のタグが一致していても、ACAが変更対象に見えることがあります。Terraformの`No changes`と同じ表示にはならない点に注意が必要です。
