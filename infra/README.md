# インフラ

同じ検証環境をTerraformとBicepのどちらでも作れるよう、実装を分けています。

| ディレクトリ | 内容 |
| --- | --- |
| [`terraform/`](terraform/) | Azureリソース、RBAC、OIDC、GitHub ActionsのRepository Variablesを管理 |
| [`bicep/`](bicep/) | Terraform版と同じAzureリソース、RBAC、OIDCを管理 |

両方のAzureリソース名と主な設定は同じです。同じSubscriptionへ同時に作る構成ではありません。片方の検証環境を削除してから、もう片方を作成します。

GitHubのRepository VariablesはBicepの対象外です。Bicep版で検証するときは、作成したリソースの値をGitHub側へ設定します。
