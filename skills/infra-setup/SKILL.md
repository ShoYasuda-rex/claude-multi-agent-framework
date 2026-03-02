---
name: infra-setup
description: 本番インフラの初期セットアップ（Git初期化・GitHub作成・プラットフォーム作成・デプロイ設定・ドメイン・DBバックアップ・ブランチ戦略・エラーハンドリング・監視）
tools: Read, Glob, Grep, Bash, Write, Edit, AskUserQuestion, Task
user_invocable: true
model: opus
---

# infra-setup

本番運用の基盤をセットアップする（1回きり）。

---

## 前提チェック

プロジェクトの `CLAUDE.md` を読む。

- `infra-setup: done` が**ある** → 「セットアップ済みです」と案内して終了
- `infra-setup: done` が**ない** → セットアップ開始

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

Step 6（DBバックアップ確認） + Step 7（ブランチ確認） + Step 8a（エラーハンドラ確認）は独立しているため、Task で並列に自動チェックを実行する。結果を集約した後、未設定の項目を順にセットアップする。

### Step 6: DBバックアップ

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

### Step 7: ブランチ戦略

`git branch -a` を**実行して**現在のブランチ構成を確認する。

mainブランチ（またはmaster）のみの場合、AskUserQuestion で質問:

> 本番ブランチに直接プッシュしています。開発用ブランチを分けますか？

選択肢: 分ける / このままでいい

**「分ける」の場合:**
- `git checkout -b develop` を実行
- CLAUDE.md に `default-branch: develop` を記録

**「このままでいい」の場合:**
- リスクを伝えた上でスキップ

### Step 8: エラーハンドリング・監視

ARCHITECTURE.md の「エラーハンドリング・監視」セクションを参照し、以下を順に実施する。

#### 8a. グローバルエラーハンドラ

Glob/Read で**自動チェック**:
- **Rails**: `ApplicationController` に `rescue_from` があるか確認
- **Express**: グローバルエラーミドルウェアがあるか確認
- **Next.js**: `error.tsx` / `_error.js` があるか確認

**存在しない場合:**
技術スタックに基づいてエラーハンドラを生成し、ユーザー確認後に書き込む。

#### 8b. エラー通知

プロジェクトで既に使っている通知チャネルを確認し、エラー通知もそこに統一する。
新しい外部サービスを増やすより、既存の仕組みに載せる方がシンプル。

**判断フロー:**
1. ARCHITECTURE.md + コード（Gemfile/package.json、通知関連サービス）から既存の通知チャネルを特定
2. 既存チャネルにエラー通知を統合する方法を提案

**例: Pushover が既にある場合（Rails）:**
1. `bundle add exception_notification` を**実行**
2. `config/initializers/exception_notification.rb` を生成して**書き込む**
   - Pushover notifier を設定（既存の環境変数 `PUSHOVER_USER_KEY` / `PUSHOVER_API_TOKEN` を使用）
3. テスト: `heroku run rails runner "raise 'test error'"` で通知が届くか確認

**例: Slack が既にある場合:**
1. `exception_notification` + Slack webhook で統合

**既存チャネルがない場合:**
AskUserQuestion で「エラー通知をどこに送りますか？」と確認（Pushover / Slack / Email / Sentry）

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

---

## 完了: CLAUDE.md に記録

CLAUDE.md に以下を記録する:

```markdown
infra-setup: done
infra-setup-items:
  # リポジトリ & プラットフォーム
  git-repo: {設定済み|既存}
  github-remote: {設定済み|既存}
  deploy-platform: {設定済み|既存|不要}
  deploy-config: {設定済み|スキップ|不要}
  domain-ssl: {設定済み|スキップ|後で}
  # 守りのインフラ
  db-backup: {設定済み|スキップ|不要}
  branch-strategy: {設定済み|スキップ}
  error-handler: {設定済み|スキップ}
  error-notification: {設定済み|スキップ}
  health-check: {設定済み|スキップ}
  uptime-monitor: {設定済み|スキップ|後で}
```

ユーザーに以下を案内する:

> インフラセットアップが完了しました。
> リリース準備ができたら `/release-setup` を実行してください。

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
