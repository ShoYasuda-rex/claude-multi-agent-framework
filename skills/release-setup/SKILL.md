---
name: release-setup
description: リリースセットアップ（環境変数・外部サービス・本番DB・スモークテスト）。コードと本番の差分を検知し設定を補助
tools: Read, Glob, Grep, Bash, Write, Edit, AskUserQuestion, Task
user_invocable: true
model: opus
---

# release-setup

本番環境の設定をアシストする。コードと本番の差分を検知し、設定を補助する。

---

## 前提チェック

プロジェクトの `CLAUDE.md` を読む。

- `infra-setup: done` が**ある** → 続行
- `infra-setup: done` が**ない** → 「先に `/infra-setup` を実行してください」と案内して終了

`docs/ARCHITECTURE.md` を読み込み、技術スタック・外部サービス依存を把握する。

---

## 独立チェックを並列実行

Step 1a（環境変数収集） + Step 2a（外部サービス特定）は独立しているため、Task で並列に自動チェックを実行する。結果を集約した後、未設定の項目を順にセットアップする。

---

### Step 1: 環境変数

#### 1a. コードから使用中の環境変数を自動収集

Grep でプロジェクト全体をスキャンし、参照している環境変数を一覧化する:

- `ENV['XXX']` / `ENV.fetch('XXX')` / `ENV.fetch("XXX"` / `ENV["XXX"]`（Ruby）
- `process.env.XXX`（Node.js）
- `os.environ['XXX']` / `os.getenv('XXX')`（Python）
- `$_ENV['XXX']` / `getenv('XXX')`（PHP）

#### 1b. .env テンプレートの確認

`.env.example` / `.env.sample` が存在するか Glob で**自動チェック**。

**存在しない場合:**
収集した環境変数から `.env.example` を生成し、ユーザー確認後に書き込む。

#### 1c. 本番環境変数の過不足チェック

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

### Step 2: 外部サービス接続

#### 2a. 外部サービス依存の自動特定

ARCHITECTURE.md + コードを**自動スキャン**して外部サービス依存を特定する:

Grep で以下のパターンをスキャン:
- API URL（`https://api.stripe.com`, `https://api.line.me` 等）
- SDK import（`require('stripe')`, `require('twilio-ruby')` 等）
- Gemfile / package.json のサービス系gem/パッケージ
- 環境変数名から推定（`STRIPE_SECRET_KEY`, `TWILIO_ACCOUNT_SID` 等）

#### 2b. 各サービスの本番設定確認

特定した外部サービスの環境変数が本番に設定済みか、Step 1c の結果を使って**自動判定**する。

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

### Step 3: 本番DB準備

DBを使っていない場合はスキップ。

#### 3a. マイグレーション状況の自動チェック

マイグレーションファイルの存在を Glob で確認し、本番のマイグレーション状況を**実行して確認**:

- **Heroku + Rails**: `heroku run rails db:migrate:status` を実行
- **Heroku + Node (Prisma)**: `heroku run npx prisma migrate status` を実行

**未実行のマイグレーションがある場合:**
「実行前にDBバックアップを確認してください」と注意喚起し、ユーザー確認後に:
- `heroku run rails db:migrate` 等を**実行**

#### 3b. 初期データ（seed）

seed ファイルが存在するか Glob で**自動チェック**。

AskUserQuestion で質問:

> 本番に初期データの投入は必要ですか？

選択肢: 必要（seed実行） / 必要（手動投入） / 不要

**「必要（seed実行）」の場合:**
「seed は冪等か確認してください」と注意喚起し、ユーザー確認後に:
- `heroku run rails db:seed` 等を**実行**

---

### Step 4: スモークテスト

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

### Step 5: 完了記録

CLAUDE.md に本番設定の状況を記録・更新する:

```markdown
prod-setup:
  env-vars: {設定済み|スキップ}
  external-services: {設定済み|スキップ|不要}
  production-db: {設定済み|スキップ|不要}
  smoke-test: {OK|NG|スキップ}
```

結果サマリーを報告する。

---

## ルール

- **確認・診断系コマンドは即実行する**（案内ではなく実行結果を見せる）
- **変更・設定系コマンドはユーザー確認後に実行する**（案内だけで終わらせない）
- AskUserQuestion は判断が必要な分岐点でのみ使う
- 外部サービスのAPIキー・シークレットは絶対にコードにハードコードしない（環境変数を案内する）
- マイグレーション・seed実行前にはバックアップの確認を促す
- 本番への破壊的操作（DB変更、force push等）は必ずユーザー確認を取る
- 「後でやる」は `後で` として記録、「不要」「このままでいい」は `スキップ` として記録
- 2回目以降の実行では、前回の記録と現状を比較し**差分のみ**を処理する

### UI操作の案内ルール

CLIで完結しない操作は、**ステップ番号付きの具体的な手順**で案内する:
- 各ステップは1アクション（クリック or 入力）
- ボタン名・メニュー名は画面の表記そのままを使う
- 入力値が決まっているものはバッククォートで具体的に提示
- 手順の最後に「次のアクション」を明示する
