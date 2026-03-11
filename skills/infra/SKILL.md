---
name: infra
description: 本番インフラの初期セットアップ（Git初期化・GitHub作成・プラットフォーム作成・デプロイ設定・ドメイン・DBバックアップ・初期データ・ブランチ戦略・エラーハンドリング・監視）
tools: Read, Glob, Grep, Bash, Write, Edit, AskUserQuestion, Task
user-invocable: true
model: opus
---

# infra

本番運用の基盤をセットアップする。後回しにした項目は再実行で設定できる。

---

## 前提チェック

プロジェクトの `rules/learned.md` が存在する場合、インフラ・デプロイ関連エントリ（Heroku, Railway, port, dyno, worker, deploy, migration 等のキーワード）を確認し、該当するパターンがあればセットアップ中に事前にチェックすること。

プロジェクトの `CLAUDE.md` を読む。

- `infra-setup: done` → 「セットアップ済みです」と案内して終了
- `infra-setup: partial` → `infra-setup-items` から `後で` の項目を抽出し、**その項目のステップだけ**再実行する
- `infra-setup` が**ない** → フルセットアップ開始

`docs/ARCHITECTURE.md` を読み込む。特に以下を把握:
- 技術スタック（言語・FW・ホスティング先）
- エラーハンドリング・監視
- 認証・権限設計
- API設計（外部サービス依存）

ARCHITECTURE.md がなければ「先に /kickoff で設計を固めよう」と伝えて終了する。

---

## Part 0: リポジトリ & プラットフォーム

以下を順に確認し、未セットアップなら実行する。既に完了している項目はスキップ。

### Step 1: Git初期化

`.git` ディレクトリの存在を確認する。

- **存在する** → スキップ
- **存在しない** → `git init` を実行

### Step 2: GitHubリポジトリ作成

`git remote -v` を**実行して**リモートの有無を確認する。

- **リモートが存在する** → スキップ
- **リモートが存在しない** → 以下を実行:
  1. `.gitignore` を確認・補完（機密ファイル・依存関係・ビルド成果物・OS/エディタファイル）
  2. `gh repo create {プロジェクト名} --private --source=. --remote=origin` を実行
     - `gh` CLI が使えない場合はユーザーに手動作成を依頼
  3. 初期コミット: 現在のファイルを個別に `git add` & commit
  4. 初期プッシュ: `git push -u origin master`

### Step 3: デプロイプラットフォーム作成

ARCHITECTURE.md の技術スタック（ホスティング先）に応じて、プラットフォームの存在を確認する。
**プラットフォームの作成はCLIで行わず、ダッシュボードでの手順を案内する。** これにより GitHub OAuth連携など、CLI経由では選べない連携方式をユーザーが選択できる。

#### 3a. 存在確認（CLIで即実行）

| ホスティング先 | 確認コマンド |
|--|--|
| Cloudflare Pages | `npx wrangler pages project list` |
| Heroku | `heroku apps:info` |
| Railway | `railway status` |
| Vercel | `vercel ls` |
| その他 | ARCHITECTURE.md の指定に従う |

**存在する** → スキップ

#### 3b. 未作成の場合 → ダッシュボードでの作成手順を案内

ホスティング先に応じた**ステップ番号付きの具体的な手順**を表示する。

**Cloudflare Pages の場合:**
1. https://dash.cloudflare.com/ を開く
2. 左メニューの「Workers & Pages」をクリック
3. 「Create」をクリック
4. 「Pages」タブを選択
5. 「Connect to Git」をクリック
6. GitHubアカウントを連携し、対象リポジトリ `{プロジェクト名}` を選択
7. ビルド設定を入力（フレームワーク・ビルドコマンド・出力ディレクトリはARCHITECTURE.mdから提示）
8. 「Save and Deploy」をクリック

**Heroku の場合:**
1. https://dashboard.heroku.com/new-app を開く
2. App name に `{プロジェクト名}` を入力
3. Region を選択（United States / Europe）
4. 「Create app」をクリック
5. Deploy タブ → 「GitHub」を選択 → リポジトリを検索して「Connect」
6. 「Enable Automatic Deploys」で自動デプロイを有効化

**Railway の場合:**
1. https://railway.com/new を開く
2. 「Deploy from GitHub repo」を選択
3. 対象リポジトリ `{プロジェクト名}` を選択
4. 設定を確認して「Deploy」

**Vercel の場合:**
1. https://vercel.com/new を開く
2. 「Import Git Repository」から対象リポジトリを選択
3. ビルド設定を確認して「Deploy」

**その他:**
ARCHITECTURE.md の指定に従い、該当プラットフォームのダッシュボード手順を案内する。

#### 3c. 完了確認

AskUserQuestion で確認:

> プラットフォームの作成は完了しましたか？

選択肢: はい、完了した / まだ（後でやる）

- **「完了した」** → 3a の確認コマンドを再実行して接続を検証 → 次のステップへ
- **「後でやる」** → `後で` として記録し次のステップへ

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

### Step 5: ドメイン・SSL

#### 5a. 現状を自動チェック

ホスティング先に応じたコマンドを**実行して**ドメイン設定を確認:

- **Heroku**: `heroku domains` を実行
- **Railway / Vercel**: 該当CLIコマンドを実行

#### 5b. 未設定の場合

AskUserQuestion で質問:

> カスタムドメインを使いますか？

選択肢: 使う（取得済み） / 使う（まだ取得していない） / デフォルトURLで運用

**「使う（取得済み）」の場合:**
ホスティング先に応じたコマンドを**実行して**設定:
- **Heroku**: `heroku domains:add example.com` を実行 → DNS設定を案内
- **その他**: 該当コマンドを実行

---

## Part A: 守りのインフラ

Step 7（DBバックアップ確認） + Step 8（ブランチ確認） + Step 9a（エラーハンドラ確認）の自動チェック部分は独立しているため、Bash ツールを **1つのメッセージ内で複数同時に** 呼び出して並列実行する。結果を集約した後、未設定の項目を順にセットアップする。

### Step 7: DBバックアップ

#### 6a. 現状を自動チェック

ホスティング先に応じたコマンドを**実行して**現状を確認する:

- **Heroku Postgres**: `heroku pg:backups:schedules` を実行してスケジュールの有無を確認
- **Railway**: `railway variables` でDB関連変数を確認
- **その他**: ユーザーに質問

#### 6b. 未設定の場合 → 設定を実行

**Heroku の場合:**
1. `heroku pg:backups:schedule DATABASE_URL --at '04:00 Asia/Tokyo'` を実行
2. `heroku pg:backups:schedules` で設定結果を確認表示
3. 復元テストの実施を推奨（`heroku pg:backups:capture` → `heroku pg:backups:url` で取得可能と案内）

**その他のホスティング:**
- AWS RDS / 自前PostgreSQL / MySQL / SQLite: 手順を案内し、可能な範囲でコマンド実行を支援

### Step 8: 初期データ（seed）

DBを使っていない場合はスキップ。

seed ファイルが存在するか Glob で**自動チェック**。

AskUserQuestion で質問:

> 本番に初期データの投入は必要ですか？

選択肢: 必要（seed実行） / 必要（手動投入） / 不要

**「必要（seed実行）」の場合:**
「seed は冪等か確認してください」と注意喚起し、ユーザー確認後に:
- `heroku run rails db:seed` 等を**実行**

### Step 9: ブランチ戦略

`git branch -a` を**実行して**現在のブランチ構成を確認する。

mainブランチ（またはmaster）のみの場合、AskUserQuestion で質問:

> 本番ブランチに直接プッシュしています。開発用ブランチを分けますか？

選択肢: 分ける / このままでいい

**「分ける」の場合:**
- `git checkout -b develop` を実行
- CLAUDE.md に `default-branch: develop` を記録

**「このままでいい」の場合:**
- リスクを伝えた上でスキップ

### Step 10: エラーハンドリング・監視

ARCHITECTURE.md の「エラーハンドリング・監視」セクションを参照し、以下を順に実施する。

#### 8a. グローバルエラーハンドラ

Glob/Read で**自動チェック**:
- **Rails**: `ApplicationController` に `rescue_from` があるか確認
- **Express**: グローバルエラーミドルウェアがあるか確認
- **Next.js**: `error.tsx` / `_error.js` があるか確認

**存在しない場合:**
技術スタックに基づいてエラーハンドラを生成し、ユーザー確認後に書き込む。

#### 8b. エラー監視（Sentry）

Sentry をエラー監視基盤として導入する（推奨）。
単なる通知ではなく、エラーの自動分類・スタックトレース・影響ユーザー数の集約ができる。

**1. 既存の Sentry 導入を自動チェック**

Grep で Sentry SDK の有無を確認:
- `package.json` に `@sentry/node` / `@sentry/browser` / `@sentry/cloudflare` 等
- `Gemfile` に `sentry-ruby` / `sentry-rails`
- コード内に `Sentry.init` / `Sentry.captureException`

**導入済み** → DSN が環境変数になっているか確認 → スキップ

**2. 未導入の場合 → セットアップ**

AskUserQuestion で確認:

> エラー監視に Sentry を導入します（推奨）。Sentry はエラーの自動分類・集約・分析ができ、後から `/sentry` スキルで本番エラーを一括分析できます。

選択肢: Sentry を導入する（Recommended） / 別の方法を使う / スキップ

**「Sentry を導入する」の場合:**

a. **Sentry プロジェクト作成を案内**（ダッシュボード操作）:
   1. https://sentry.io/organizations/ を開く（アカウントがなければ無料で作成）
   2. 「Create Project」をクリック
   3. プラットフォームを選択（技術スタックに応じて提示）
   4. プロジェクト名に `{プロジェクト名}` を入力
   5. 「Create Project」をクリック
   6. 表示される DSN をコピー

b. AskUserQuestion で「Sentry の DSN を入力してください」と確認

c. **SDK をインストール**（技術スタックに応じて実行）:

| スタック | コマンド |
|---------|---------|
| Node.js / Workers | `npm install @sentry/node` or `@sentry/cloudflare` |
| Rails | `bundle add sentry-ruby sentry-rails` |
| Next.js | `npx @sentry/wizard@latest -i nextjs` |
| ブラウザのみ（バニラJS） | CDN スクリプトタグを追加 |

d. **初期化コードを生成して書き込む**（技術スタックに応じたファイルに）

e. **DSN を環境変数として設定**:
   - ローカル: `.env` に `SENTRY_DSN=...` を追加
   - 本番: ホスティング先の環境変数設定を案内

f. **動作確認**: テストエラーを発生させ、Sentry ダッシュボードに表示されるか確認

**「別の方法を使う」の場合:**
既存の通知チャネル（Pushover / Slack 等）にエラー通知を統合する方法を提案・実行する。

#### 8c. ヘルスチェックエンドポイント

Glob/Grep で `/health` または `/up` エンドポイントが存在するか**自動チェック**する。

**存在しない場合:**
技術スタックに応じたヘルスチェックエンドポイントを生成（DB接続確認含む）し、ユーザー確認後に書き込む。

**存在する場合:**
本番URLに対して `curl` でヘルスチェックを**実行して**応答を確認する（URLがわかる場合）。

#### 8d. 死活監視

AskUserQuestion で質問:

> 死活監視は設定済みですか？

選択肢: 設定済み / まだ / 本番公開していない

**「まだ」の場合:**
- UptimeRobot（無料、5分間隔）の登録手順を案内

#### 8e. Dependabot（脆弱性・依存更新の自動検知）

`.github/dependabot.yml` の有無を Glob で**自動チェック**する。

**存在する** → スキップ

**存在しない場合:**

ARCHITECTURE.md の技術スタックからパッケージエコシステムを判定し、`.github/dependabot.yml` を Write で生成する。

```yaml
version: 2
updates:
  # npm の場合
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5

  # bundler の場合
  - package-ecosystem: "bundler"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5

  # pip の場合
  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
```

- 技術スタックに該当するエコシステムのみ含める（不要なものは削除）
- GitHub Actions を使っている場合は `github-actions` エコシステムも追加する
- 通知はGitHubデフォルトのメール通知（緊急性が低いため Pushover 不要）

#### 8f. 通知設定

Sentry と UptimeRobot の通知先をまとめて設定する。両方のアラートを1箇所に集約することで、監視の見落としを防ぐ。

AskUserQuestion で質問:

> Sentry と UptimeRobot の通知をどこに送りますか？

選択肢: メール通知（Recommended） / Slack / スキップ

**「メール通知」の場合:**

Sentry・UptimeRobot ともにデフォルトでアカウントのメールアドレスに通知が届く。追加設定は不要だが、以下を確認する:

1. **Sentry**: Settings → Account → Notifications でメール通知が有効か確認を案内
2. **UptimeRobot**: My Settings → Alert Contacts にメールが登録されているか確認を案内

**「Slack」の場合:**
- Sentry: Settings → Integrations → Slack を案内
- UptimeRobot: Alert Contacts → Slack Webhook を案内

---

## 完了: CLAUDE.md に記録

### Git 運用セクションの追記

CLAUDE.md に「Git 運用」セクションが**存在しない場合**、セットアップ中に確認したリモートとブランチ情報から自動生成して追記する。

`git remote -v` と `git branch --show-current` の結果を使い、以下の形式で書き込む:

```markdown
## Git 運用

- リモート: `{remote1}`（{platform1}: {url1}）, `{remote2}`（{platform2}: {url2}）
- ブランチ戦略: `{branch}` に直接push（`git push {remote1} {branch}` && `git push {remote2} {branch}`）
- 本番ブランチ: `{branch}`
```

- リモートが1つの場合は `&&` 以降を省略する
- リモートが `heroku` の場合は platform を「Heroku」、`origin` で GitHub URL なら「GitHub: {user/repo}」とする
- 既に「Git 運用」セクションがある場合はスキップする

### infra-setup 記録

CLAUDE.md に以下を記録する。`infra-setup-items` に `後で` が**1つでもあれば** `partial`、**なければ** `done` を設定する:

```markdown
infra-setup: {done|partial}
infra-setup-items:
  # リポジトリ & プラットフォーム
  git-repo: {設定済み|既存}
  github-remote: {設定済み|既存}
  deploy-platform: {設定済み|既存|不要}
  deploy-config: {設定済み|スキップ|不要}
  domain-ssl: {設定済み|スキップ|後で}
  # 守りのインフラ
  db-backup: {設定済み|スキップ|不要}
  seed-data: {設定済み|スキップ|不要}
  branch-strategy: {設定済み|スキップ}
  error-handler: {設定済み|スキップ}
  sentry: {設定済み|スキップ|別の方法}
  health-check: {設定済み|スキップ}
  uptime-monitor: {設定済み|スキップ|後で}
  dependabot: {設定済み|スキップ}
  notification: {設定済み|スキップ}
```

ユーザーに以下を案内する:

- **done の場合**: 「インフラセットアップが完了しました。`/deploy safe` で本番設定チェック付きデプロイができます。」
- **partial の場合**: 「インフラセットアップを記録しました。`後で` の項目があります。準備ができたら再度 `/infra` で設定できます。」

---

## ルール

- ARCHITECTURE.md を必ず読み、プロジェクトの方針に合わせてセットアップする
- **確認・診断系コマンドは即実行する**（案内ではなく実行結果を見せる）
- **変更・設定系コマンドはユーザー確認後に実行する**（案内だけで終わらせない）
- AskUserQuestion は判断が必要な分岐点でのみ使う
- セットアップモードではコードの生成・編集を行う（エラーハンドラ、通知初期化、ヘルスチェック等）
- 外部サービスのAPIキー・シークレットは絶対にコードにハードコードしない（環境変数を案内する）
- 本番への破壊的操作（DB変更、force push等）は必ずユーザー確認を取る
- 「後でやる」は `後で` として記録、「不要」「このままでいい」は `スキップ` として記録

### UI操作の案内ルール

CLIで完結しない操作は、**ステップ番号付きの具体的な手順**で案内する:
- 各ステップは1アクション（クリック or 入力）
- ボタン名・メニュー名は画面の表記そのままを使う
- 入力値が決まっているものはバッククォートで具体的に提示
- 手順の最後に「次のアクション」を明示する
