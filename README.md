# Azure Container Appsのアプリ更新をIaCから分ける検証

Azure Container Apps（ACA）のアプリ更新を、TerraformやBicepによるインフラ管理から分ける方法を試したリポジトリです。App ConfigurationをアプリのCDとIaCの受け渡し場所にできるか、実際にリソースを作って確認しました。

検証の背景、App Configurationを使わない方法との比較、TerraformとBicepでの違いは、次の記事にまとめています。

> [Azure Container Appsのイメージ更新をTerraformから分離してみた。App Configurationは必要か？](https://zenn.dev/gritio28tech/articles/e412826c92b6b8)

このリポジトリには、Terraform版とBicep版の構成、確認用のGoアプリ、GitHub Actionsのワークフローを置いています。

## 検証構成

[![GitHub Actionsによるデプロイと2つのマネージドIDの役割](docs/images/インフラ構成図.png)](docs/images/インフラ構成図.png)

実行用IDはACAがACRからイメージをpullし、GoアプリがApp ConfigurationとKey Vaultを読むために使います。デプロイ用IDはGitHub ActionsがOIDCでAzureへログインするために使います。Secretの実値はApp Configurationには置きません。

## 確認できたこと

- `app/**` の変更を `main` にpushすると、GitHub ActionsがイメージをACRへ送り、App Configurationの `app:imageTag` とACAのイメージを順に更新する。
- ブラウザーの `App Version`、App Configurationのタグ、ACAのイメージタグが一致する。
- Terraformでは、CDが更新する `app:imageTag` の値を `ignore_changes` にすることで、その後の `terraform plan` が `No changes` になる。
- ACAはコンテナの `image` だけを `ignore_changes` にできるため、Terraform版ではApp Configurationを使わずに分離する方法もある。
- Bicepには `ignore_changes` がない。App Configurationのキーを `existing` で参照すると、CDが更新したタグを戻さずに再適用できる。
- Bicepの再適用では不要なRevisionは作られなかった。ただし、`what-if`ではApp Configurationの参照値を解決できず、実際には同じ値でもACAが変更対象として表示される。

## 検証費用（2026年9月22日時点）

9月13日から検証を始め、ACAは動作確認するとき以外は停止しています。Azure Cost Managementの表示は**合計182円、平均26円/日**でした。

![リソース別の検証費用](docs/images/azure-cost-by-resource.png)

費用の大半はACRです。画面にはACRが2行あり、それぞれ173円と9円。Key Vaultは各1円未満、App Configurationは0円で、ACAの費用はこの内訳には表示されていません。

![日別の検証費用](docs/images/azure-cost-daily.png)

参考までに、9月15日の費用は26.54円でした。ACAを止めていても、[ACR Basicには日額の料金](https://azure.microsoft.com/en-us/pricing/details/container-registry/)がかかります。検証が終わったら、料金が増え続けないよう `terraform destroy` で片付けます。ACA周りは一度で消えないことがあったので、削除後はAzure側とstateも確認します。

## ディレクトリ構成

```text
.
├── app/                         # Goアプリ、Dockerfile、画面と値の流れ
├── infra/
│   ├── terraform/               # Terraform版
│   ├── bicep/                   # Bicep版
│   └── README.md                # 2つの実装の使い分け
├── .github/workflows/
│   └── app-deploy.yaml           # アプリのビルドとデプロイ
├── docs/images/                  # このREADMEで使う費用の画像
├── README.md
└── LICENSE
```

アプリの動きは[app/README.md](app/README.md)、初回構築と動作確認は[infra/README.md](infra/README.md)にまとめています。
