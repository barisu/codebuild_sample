# CodeBuild Sample Project

AWS CodeBuild、S3、CodeCommitを使用したビルドパイプラインのサンプルプロジェクトです。

## 構成

- **CloudFormation**: 全リソースの定義
- **CodeCommit**: ソースコードリポジトリ
- **CodeBuild**: ビルド処理
- **S3**: ビルド成果物の保存

## ファイル構成

```
├── cloudformation.yaml  # CloudFormationテンプレート
├── buildspec.yml       # CodeBuildビルド仕様
├── Makefile           # 自動化コマンド
└── README.md          # このファイル
```

## セットアップ

### 1. スタックのデプロイ

```bash
make setup
```

または個別に実行：

```bash
# テンプレート検証
make validate

# デプロイ
make deploy
```

### 2. リポジトリのクローンと設定

```bash
# リポジトリをクローン
make clone-repo

# CodeCommit用認証設定（このリポジトリのみ）
cd source-code
git config credential.helper 'aws codecommit credential-helper $@'
git config credential.UseHttpPath true
```

### 3. ソースコードの追加とプッシュ

```bash
cd source-code
# ソースコードを追加
cp ../buildspec.yml .
# その他必要なファイルを追加

# プッシュ
make push-code
```

### 4. ビルドの実行

```bash
# ビルド開始
make start-build

# ビルド状況確認
make build-status

# 最近のビルド一覧
make list-builds
```

## 利用可能なコマンド

| コマンド | 説明 |
|---------|------|
| `make help` | ヘルプ表示 |
| `make setup` | 検証とデプロイを一括実行 |
| `make deploy` | CloudFormationスタックのデプロイ |
| `make delete` | スタック削除 |
| `make status` | スタック状況確認 |
| `make outputs` | スタック出力値表示 |
| `make validate` | テンプレート検証 |
| `make clone-repo` | CodeCommitリポジトリクローン |
| `make push-code` | コードプッシュ |
| `make start-build` | ビルド開始 |
| `make build-status` | ビルド状況確認 |
| `make list-builds` | 最近のビルド一覧 |
| `make cleanup` | 全リソース削除 |

## buildspec.yml の設定

`buildspec.yml`では以下の処理を行います：

1. **pre_build**: 依存関係のインストール
2. **build**: ソースコードのコンパイル
3. **post_build**: testフォルダのtar.gz化

成果物として`test.tar.gz`がS3バケットに保存されます。

## セキュリティ

- CodeBuildサービスロールは最小権限で設定
- S3バケットは暗号化とパブリックアクセス拒否を設定
- CloudWatch Logsへのアクセスは必要最小限に制限

## トラブルシューティング

### 認証エラー

```bash
# AWS認証情報確認
aws sts get-caller-identity

# 認証ヘルパー再設定
git config credential.helper 'aws codecommit credential-helper $@'
git config credential.UseHttpPath true
```

### ビルドエラー

```bash
# ビルドログ確認
aws logs describe-log-groups --log-group-name-prefix /aws/codebuild/sample-build-project
```

## クリーンアップ

全リソースを削除する場合：

```bash
make cleanup
```

これによりS3バケット内のファイルを削除後、CloudFormationスタックが削除されます。