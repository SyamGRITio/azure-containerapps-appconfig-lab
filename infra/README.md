# Infrastructure Setup

## 前提

このPoCでは以下を分離しています。

- Terraform: インフラ構築
- 手動 / CI/CD: アプリケーションイメージのbuild・push
- App Configuration: デプロイ対象のimage tag管理
- Key Vault: Secret実値管理

そのため、初回構築時は `terraform apply` 一発ではなく、段階的に作成します。

---

## 初回構築フロー

### 1. 基盤リソースを作成

まず以下を作成します。

- Resource Group
- ACR
- App Configuration
- Key Vault
- UAMI
- Container Apps Environment
- Terraform実行者用RBAC

```powershell
terraform apply ...
※ 実際に使用したtargetコマンドをここへ記載。
2. アプリケーションイメージをACRへpush
リポジトリルートで実行。
$IMAGE_TAG = git rev-parse --short HEAD
$ACR_LOGIN_SERVER = "acrappcofigpoc20260921.azurecr.io"

az acr login --name acrappcofigpoc20260921

docker build `
  -t "$ACR_LOGIN_SERVER/aca-app:$IMAGE_TAG" `
  ./app

docker push "$ACR_LOGIN_SERVER/aca-app:$IMAGE_TAG"
3. App Configuration / Key Vaultのリソースを作成
ACAはまだ作成しません。
terraform apply `
  "-target=azurerm_app_configuration_key.image_tag" `
  "-target=azurerm_app_configuration_key.message" `
  "-target=azurerm_app_configuration_key.secret_message" `
  "-target=azurerm_key_vault_secret.app_secret_message"
4. App ConfigurationのimageTagを更新
$IMAGE_TAG = git rev-parse --short HEAD

az appconfig kv set `
  --name appcs-aca-appconfig-poc `
  --key app:imageTag `
  --label dev `
  --value $IMAGE_TAG `
  --auth-mode login `
  --yes
5. Key Vault Secretの実値を設定
az keyvault secret set `
  --vault-name kv-appconfig-poc20260921 `
  --name app-secret-message `
  --value "<secret>"
Terraform側ではSecret値を ignore_changes しているため、
実値はTerraform外で管理します。
6. 残りを通常apply
terraform apply
ACAはruntime UAMIのRBAC作成後に作成する必要があるため、
azurerm_container_app.main に以下を設定しています。
depends_on = [
  azurerm_role_assignment.aca_runtime
]
動作確認
terraform plan
期待値:
No changes. Your infrastructure matches the configuration.
ACA確認:
az containerapp show ...
App Configuration確認:
az appconfig kv show ...
ブラウザでは以下を確認。
- App VersionがGit SHAと一致
- App Configurationのメッセージを取得できる
- Key Vault Secretを取得できる
注意点
App Configuration
app:imageTag はTerraformでキー自体を作成しますが、
値はCI/CD側で更新します。
lifecycle {
  ignore_changes = [value]
}
Key Vault
Secret resourceはTerraformで作りますが、
実値はTerraform外で更新します。
lifecycle {
  ignore_changes = [value]
}
ACA作成時のRBAC
depends_on がない状態では、初回作成時にACR Pullが
UNAUTHORIZED
となりRevision作成に失敗しました。
そのためruntime UAMIのRBAC作成後にACAを作成するようにしています。
AzureRM Providerのdestroy時エラー
Container App / Container Apps Environment削除時に、
Azure上では削除済みでもprovider側のpollingでエラーになることがあります。
その場合はAzure側でResourceNotFoundを確認したうえで、
再度 terraform destroy を実行するとstateが追従しました。

これくらい残しておけば、あとでCI/CD化した後も、

```text
手動ならどうやるか
↓
CI/CDではどこを自動化しているか
の対応が見やすいです。
特に今回のZenn記事では、**「最初は手動でこの順番を検証し、その後GitHub Actionsへ置き換えた」**という流れがそのまま記事の説明にも使えます。