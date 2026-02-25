---
name: infra-setup-connect
description: 本番接続セットアップ（デプロイ設定・環境変数・外部サービス・ドメイン・本番DB・スモークテスト・完了記録）
tools: Read, Glob, Grep, Bash, Write, Edit, AskUserQuestion, Task
user_invocable: true
model: opus
---

# infra-setup-connect（Part B: 本番接続 + 完了）

デプロイ設定・環境変数・外部サービス・ドメイン・本番DBをセットアップし、スモークテストで動作確認する。

---

## 前提チェック

プロジェクトの `CLAUDE.md` を読む。

- `infra-setup-progress: partA` が**ある** → 続行
- `infra-setup-progress: partA` が**ない** → 「先に `/infra-setup-guard` を実行してください」と案内して終了

`docs/ARCHITECTURE.md` を読み込み、技術スタック・外部サービス依存を把握する。

---

## Part B の独立チェックを並列実行

Step 4（デプロイ設定確認） + Step 5a（環境変数収集） + Step 6a（外部サービス特定）は独立しているため、Task で並列に自動チェックを実行する。結果を集約した後、未設定の項目を順にセットアップする。

---

### Step 4: デプロイ設定

#### 4a. 設定ファイルの自動チェック

Glob で**プロジェクトルートを自動スキャン**し、以下の有無をチェック:

| ホスティング先 | 必要なファイル |
|--------------|--------------|
| Heroku | `Procfile` |
| Railway | `Procfile` or `railway.json` or `nixpacks.toml` |
| Vercel | `vercel.json`（任意） |
| Render | `render.yaml`（任意） |
| AWS | `Dockerfile` or `buildspec.yml` |
| Docker系 | `Dockerfile`, `docker-compose.yml` |

**不足がある場合:**
技術スタックに応じた設定ファイルを生成し、ユーザー確認後に書き込む。

#### 4b. ビルド設定の確認

Gemfile / package.json 等を Read で確認し、本番ビルドに必要な依存が揃っているか検証する。

**問題がある場合:**
修正を提案し、ユーザー確認後に実行。

#### 4c. FTPデプロイのワークフロー生成

CLAUDE.md または ARCHITECTURE.md の技術スタック（ホスティング先）に「WebARENA」「FTP」「共用サーバー」等の記載があるか確認する。

**該当しない** → スキップ

**該当する** → `.github/workflows/deploy.yml` が既に存在するか Glob で確認する:

- **存在する** → スキップ
- **存在しない** → 以下を順に実行:

**1. FTP接続情報をヒアリング**

AskUserQuestion で以下を聞く（1回の呼び出しにまとめる）:

**質問A: FTPサーバーのホスト名**
- Other で直接入力（例: `example.com`）

**質問B: FTPのアップロード先ディレクトリ**
- `/public_html`（Recommended）
- `/httpdocs`
- `/`
- Other で直接入力

**2. ワークフローファイルを自動生成**

`.github/workflows/` ディレクトリを作成し、`deploy.yml` を Write で作成する:

```yaml
name: Deploy to FTP

on:
  push:
    branches:
      - {ブランチ名}

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: FTP Deploy
        uses: SamKirkland/FTP-Deploy-Action@v4.3.5
        with:
          server: ${{ secrets.FTP_SERVER }}
          username: ${{ secrets.FTP_USERNAME }}
          password: ${{ secrets.FTP_PASSWORD }}
          server-dir: ${{ secrets.FTP_SERVER_DIR }}
          exclude: |
            **/.git*
            **/.git*/**
            .github/**
            .claude/**
            docs/**
            composer.json
            composer.lock
            CLAUDE.md
            README.md
```

**3. CLAUDE.md にデプロイ情報を追記**

Git 運用セクションに以下を追加:

```markdown
- デプロイ: GitHub Actions → FTP自動デプロイ（`.github/workflows/deploy.yml`）
- FTP接続情報: GitHub Secrets（`FTP_SERVER`, `FTP_USERNAME`, `FTP_PASSWORD`, `FTP_SERVER_DIR`）
```

**4. GitHub Secrets の登録を案内し、確認を待つ**

**必ず**以下のメッセージを表示する。**ユーザーが Secrets 登録済みと回答するまで次のステップに進まない。**

---

**GitHub Secrets の設定が必要です。** 以下の4つを GitHub リポジトリに登録してください:

1. リポジトリの **Settings → Secrets and variables → Actions** を開く
2. 「New repository secret」から以下を追加:

| Secret名 | 値 |
|---|---|
| `FTP_SERVER` | {ヒアリングで得たホスト名} |
| `FTP_USERNAME` | FTPユーザー名 |
| `FTP_PASSWORD` | FTPパスワード |
| `FTP_SERVER_DIR` | {ヒアリングで得たディレクトリ} |

設定後、`master` への push で自動的にFTPデプロイが実行されます。

---

AskUserQuestion で「Secrets を登録しましたか？」と確認する:
- 「はい、登録した」→ 次のステップへ
- 「まだ」→ 登録を待つ

---

### Step 5: 環境変数

#### 5a. コードから使用中の環境変数を自動収集

Grep でプロジェクト全体をスキャンし、参照している環境変数を一覧化する:

- `ENV['XXX']` / `ENV.fetch('XXX')` / `ENV.fetch("XXX"` / `ENV["XXX"]`（Ruby）
- `process.env.XXX`（Node.js）
- `os.environ['XXX']` / `os.getenv('XXX')`（Python）
- `$_ENV['XXX']` / `getenv('XXX')`（PHP）

#### 5b. .env テンプレートの確認

`.env.example` / `.env.sample` が存在するか Glob で**自動チェック**。

**存在しない場合:**
収集した環境変数から `.env.example` を生成し、ユーザー確認後に書き込む。

#### 5c. 本番環境変数の過不足チェック

ホスティング先に応じたコマンドを**実行して**本番の環境変数を取得し、コードの参照と照合する:

- **Heroku**: `heroku config` を実行
- **Railway**: `railway variables` を実行
- **Vercel**: `vercel env ls` を実行

**照合結果を表示:**
```
環境変数チェック:
✅ DATABASE_URL: 本番に設定済み
✅ SECRET_KEY_BASE: 本番に設定済み
❌ DEEPL_API_KEY: コードで参照あり、本番に未設定
⚠️ SENTRY_DSN: コードで参照あり、本番に未設定（新規追加分）
```

未設定の変数は `heroku config:set KEY=value` 等のコマンドを提示し、値の入力を求める。

---

### Step 6: 外部サービス接続

#### 6a. 外部サービス依存の自動特定

ARCHITECTURE.md + コードを**自動スキャン**して外部サービス依存を特定する:

Grep で以下のパターンをスキャン:
- API URL（`https://api.stripe.com`, `https://api.line.me` 等）
- SDK import（`require('stripe')`, `require('twilio-ruby')` 等）
- Gemfile / package.json のサービス系gem/パッケージ
- 環境変数名から推定（`STRIPE_SECRET_KEY`, `TWILIO_ACCOUNT_SID` 等）

#### 6b. 各サービスの本番設定確認

特定した外部サービスの環境変数が本番に設定済みか、Step 5c の結果を使って**自動判定**する。

**未設定のサービスがある場合:**
AskUserQuestion でまとめて確認:

> 以下の外部サービスの本番APIキーが未設定です。どうしますか？
> - {サービスA}: {必要な環境変数}
> - {サービスB}: {必要な環境変数}

選択肢: 今設定する / 後で設定する / このプロジェクトでは使わない

**「今設定する」の場合:**
サービスごとに:
1. APIキー取得先のURL/手順を案内
2. ユーザーがキーを提供したら `heroku config:set` 等で**実行して設定**
3. 接続テスト: 可能なら `heroku run rails runner "..."` 等で**接続確認を実行**

**Webhook URLが必要なサービスの場合:**
- `heroku domains` を実行して本番URLを取得
- Webhook設定先のURLを具体的に提示

---

### Step 7: ドメイン・SSL

#### 7a. 現状を自動チェック

ホスティング先に応じたコマンドを**実行して**ドメイン設定を確認:

- **Heroku**: `heroku domains` を実行
- **Railway / Vercel**: 該当CLIコマンドを実行

#### 7b. 未設定の場合

AskUserQuestion で質問:

> カスタムドメインを使いますか？

選択肢: 使う（取得済み） / 使う（まだ取得していない） / デフォルトURLで運用

**「使う（取得済み）」の場合:**
ホスティング先に応じたコマンドを**実行して**設定:
- **Heroku**: `heroku domains:add example.com` を実行 → DNS設定を案内
- **その他**: 該当コマンドを実行

---

### Step 8: 本番DB準備

DBを使っていない場合（Part A の Step 1 で「不要」）はスキップ。

#### 8a. マイグレーション状況の自動チェック

マイグレーションファイルの存在を Glob で確認し、本番のマイグレーション状況を**実行して確認**:

- **Heroku + Rails**: `heroku run rails db:migrate:status` を実行
- **Heroku + Node (Prisma)**: `heroku run npx prisma migrate status` を実行

**未実行のマイグレーションがある場合:**
⚠️ 「実行前にDBバックアップを確認してください」と注意喚起し、ユーザー確認後に:
- `heroku run rails db:migrate` 等を**実行**

#### 8b. 初期データ（seed）

seed ファイルが存在するか Glob で**自動チェック**。

AskUserQuestion で質問:

> 本番に初期データの投入は必要ですか？

選択肢: 必要（seed実行） / 必要（手動投入） / 不要

**「必要（seed実行）」の場合:**
⚠️ 「seed は冪等か確認してください」と注意喚起し、ユーザー確認後に:
- `heroku run rails db:seed` 等を**実行**

---

### Step 9: スモークテスト

本番URLがわかる場合、以下を**実行して**基本動作を確認:

1. `curl -s -o /dev/null -w "%{http_code}" {本番URL}/up` でヘルスチェック
2. `curl -s -o /dev/null -w "%{http_code}" {本番URL}` でトップページ応答確認
3. SSL証明書: `curl -vI https://{本番URL} 2>&1 | grep "SSL certificate"` で確認

結果を表示:
```
スモークテスト:
✅ ヘルスチェック (/up): 200 OK
✅ トップページ: 200 OK
✅ SSL証明書: 有効
```

---

### Step 10: 完了記録

全項目の確認後、CLAUDE.md の `infra-setup-progress` 行を削除し、以下に置き換える:

```markdown
infra-setup: done
infra-setup-items:
  ...（既存の Part 0 + Part A 項目）...
  # Part B: 本番接続
  deploy-config: {設定済み|スキップ|不要}
  env-vars: {設定済み|スキップ}
  external-services: {設定済み|スキップ|不要}
  domain-ssl: {設定済み|スキップ|後で}
  production-db: {設定済み|スキップ|不要}
  smoke-test: {OK|NG|スキップ}
```

結果サマリーを報告する:

> インフラセットアップが完了しました。次回 `/infra-setup` を実行すると検証モードで全項目をチェックできます。

---

## ルール

- **確認・診断系コマンドは即実行する**（案内ではなく実行結果を見せる）
- **変更・設定系コマンドはユーザー確認後に実行する**（案内だけで終わらせない）
- AskUserQuestion は判断が必要な分岐点でのみ使う
- セットアップモードではコードの生成・編集を行う（Procfile、デプロイ設定、FTPワークフロー等）
- 外部サービスのAPIキー・シークレットは絶対にコードにハードコードしない（環境変数を案内する）
- マイグレーション・seed実行前にはバックアップの確認を促す
- 本番への破壊的操作（DB変更、force push等）は必ずユーザー確認を取る
- 「後でやる」は `後で` として記録、「不要」「このままでいい」は `スキップ` として記録

### UI操作の案内ルール

CLIで完結しない操作は、**ステップ番号付きの具体的な手順**で案内する:
- 各ステップは1アクション（クリック or 入力）
- ボタン名・メニュー名は画面の表記そのままを使う
- 入力値が決まっているものはバッククォートで具体的に提示
- 手順の最後に「次のアクション」を明示する
