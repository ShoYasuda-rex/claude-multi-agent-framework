---
name: deploy
description: add・commit・pushを実行。「/deploy」で即実行、「/deploy safe」で安全チェック付き
model: sonnet
user_invocable: true
---

# Git Deploy

add → commit → push を実行するスキル。CLAUDE.md の Git 設定に従う。

## モード判定

引数から実行モードを判定する:

- **引数なし / `quick`** → **Quick モード**（即実行、確認なし）
- **`safe`** → **Safe モード**（安全バリデーション + ユーザー確認付き）

---

## 共通手順

### 1. Git設定を読み取る

プロジェクトの CLAUDE.md（カレントディレクトリの `CLAUDE.md`）を Read で読む。
「Git 運用」「Git」等のセクションから以下を探す:

- **リモート名**（例: `origin`）
- **ブランチ戦略**（例: `同名ブランチ`, `main に直接` 等）
- **デプロイ方式**（例: `GitHub Actions → FTP自動デプロイ`, `Heroku` 等）

**Git 設定が見つかった** → ステップ 2 へ
**Git 設定が見つからない** → ステップ 1.1 へ

#### 1.1. 設定がない場合 → ARCHITECTURE.md を参照、それでもなければユーザーに聞く

1. まず `docs/ARCHITECTURE.md` を Read で読み、「技術スタック」テーブルの「ホスティング」行からプッシュ先を推定する:
   - `Cloudflare Pages` → リモート: `origin`
   - `Heroku` → リモート: `heroku`
   - `WebARENA SuiteX` → リモート: `origin`（GitHub Actions FTPデプロイ）
2. ブランチ名は ARCHITECTURE.md から読み取れないので AskUserQuestion で聞く
3. 推定したプッシュ先をユーザーに確認し、CLAUDE.md に記録する

ARCHITECTURE.md も存在しない場合、AskUserQuestion で以下を聞く:

**質問1: ブランチ**
- `master`（Recommended）
- Other で直接入力

**質問2: プッシュ先**
- `Cloudflare Pages（リモート: origin）`（Recommended）
- `Heroku（リモート: heroku）`
- `WebARENA SuiteX（リモート: origin → GitHub Actions FTPデプロイ）`
- Other で直接入力（リモート名を指定）

リモート名はプッシュ先から自動決定する:
- Cloudflare Pages → `origin`
- Heroku → `heroku`
- WebARENA SuiteX → `origin`（GitHub Actionsが自動でFTPデプロイ）

回答を得たら、CLAUDE.md に「Git 運用」セクションを追記する:

```markdown
## Git 運用

- リモート: `origin`（GitHub: user/repo）
- ブランチ戦略: `master` に直接push（`git push origin master`）
- 本番ブランチ: `master`
```

#### 1.2. git remote の存在確認

`git remote` を実行し、CLAUDE.md で指定されたリモート（例: `origin`）が存在するか確認する。

- **リモートが存在する** → ステップ 2 へ進む
- **リモートが存在しない** → AskUserQuestion でリポジトリパスを聞く:

**質問A: プロトコル**
- `SSH（git@github.com:）`（Recommended）
- `HTTPS（https://github.com/）`

**質問B: GitHubリポジトリ（user/repo 形式）**
- Other で直接入力（例: `user/my-project`）

選択に応じて URL を組み立てる:
- SSH → `git remote add {remote} git@github.com:{user/repo}.git`
- HTTPS → `git remote add {remote} https://github.com/{user/repo}.git`

実行後、CLAUDE.md の「Git 運用」セクションにリポジトリ情報を追記する。

---

### 2. デプロイ設定を確認する

CLAUDE.md の Git 運用セクションに「FTP」「GitHub Actions」「deploy.yml」のいずれかが含まれているか確認する。

**含まれていない** → ステップ 3 へスキップ（FTP不要のプロジェクト）

**含まれている（FTPデプロイが必要）** → 以下を順に実行:

#### 2.1. ワークフローファイルの存在チェック

`.github/workflows/deploy.yml` が既に存在するか Glob で確認する。

- **存在する** → ステップ 3 へスキップ
- **存在しない** → ステップ 2.2 へ

#### 2.2. FTP接続情報をヒアリング

AskUserQuestion で以下を聞く（1回の呼び出しにまとめる）:

**質問A: FTPサーバーのホスト名**
- Other で直接入力（例: `example.com`）

**質問B: FTPのアップロード先ディレクトリ**
- `/public_html`（Recommended）
- `/httpdocs`
- `/`
- Other で直接入力

#### 2.3. ワークフローファイルを自動生成

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

#### 2.4. CLAUDE.md にデプロイ情報を追記

Git 運用セクションに以下を追加:

```markdown
- デプロイ: GitHub Actions → FTP自動デプロイ（`.github/workflows/deploy.yml`）
- FTP接続情報: GitHub Secrets（`FTP_SERVER`, `FTP_USERNAME`, `FTP_PASSWORD`, `FTP_SERVER_DIR`）
```

#### 2.5. GitHub Secrets の登録を案内し、確認を待つ

ワークフローファイルを新規作成した場合、**必ず**以下のメッセージを表示する。
**ユーザーが Secrets 登録済みと回答するまで push しない。**

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
- 「はい、登録した」→ ステップ 3 へ
- 「まだ」→ 登録を待つ（push しない）

---

### 3. 状態確認（並列実行）

以下を並列で実行:

- `git status` — 変更ファイルの確認
- `git branch --show-current` — 現在のブランチ名
- `git remote -v` — リモートの確認
- `git log --oneline -5` — 直近コミット（メッセージスタイル確認用）

変更がなければ「変更なし」と報告して終了。

### 4. DB スキーマ変更チェック（Quick / Safe 共通）

**両モードで必ず実行する。** ステップ 3 の `git status` 結果を参照し、以下を確認:

- `*.sql` ファイル（`schema.sql`, マイグレーションファイル等）が変更に含まれる場合、**ユーザーに警告して確認を取る**:
  - 「DB スキーマ変更が含まれています。本番DBへのマイグレーションが別途必要です。続行しますか？」
  - ユーザーが承認 → 次のステップへ
  - ユーザーが拒否 → 処理を中止

### 5. 【Safe モードのみ】安全バリデーション

**Quick モードではこのステップをスキップする。**

以下のいずれかに該当する場合、**ユーザーに警告して確認を取る**:

- **保護ブランチ**: `main` / `master` / `production` ブランチへの直接プッシュ
- **機密ファイル**: `.env`, `credentials`, `secret`, `*.pem`, `*.key` などがステージング対象に含まれる場合
- **変更なし**: 未コミットの変更も未プッシュのコミットもない場合 → 処理を中止（未プッシュのコミットがある場合はステップ 9 へスキップ）
- **環境変数追加**: diff 内に新しい `env.` 参照（`env.XXXX` や `process.env.XXXX`）が追加されている場合、本番環境への設定漏れがないか確認を促す

### 6. 【Safe モードのみ】差分の確認

**Quick モードではこのステップをスキップする。**

- `git diff` と `git diff --cached` で変更内容を確認する
- 変更ファイルの一覧と概要をユーザーに表示する

### 7. add & commit

- 変更ファイルを個別に `git add <file>` でステージング（`git add -A` / `git add .` は使わない）
- `.env`, `credentials`, `*.key`, `*.pem` 等の機密ファイルはステージングしない
- 変更内容からコミットメッセージを自動生成し、確認なしでコミットする
- HEREDOC 形式で渡す:

```
git commit -m "$(cat <<'EOF'
コミットメッセージ

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

### 8. 【Safe モードのみ】リモートとの同期チェック

**Quick モードではこのステップをスキップする。**

- `git fetch` でリモートの最新状態を取得
- `git status` でリモートとの差分を確認
- コンフリクトがある場合はユーザーに報告して指示を仰ぐ

### 8.5. 【Safe モードのみ】デプロイ前ログチェック

**Quick モードではこのステップをスキップする。**

log-checker サブエージェント（subagent_type: log-checker）を起動し、本番ログの異常を確認する。

- エラー率上昇・レスポンスタイム劣化・OOM等の予兆がないか
- **異常なし** → ステップ 9 へ
- **異常あり** → ユーザーに警告し、続行するか確認を取る
  - 続行 → ステップ 9 へ
  - 中止 → 処理を終了

### 9. push

- CLAUDE.md の設定に従ってプッシュを実行: `git push {remote} {branch}`
  - 例: `git push origin master`, `git push heroku master`
- 失敗した場合はエラー内容を報告

### 10. 完了報告

#### Quick モード
- ブランチ名、コミット内容、プッシュ先を1行で報告
- **FTPデプロイの場合**: GitHub Actions の実行状況を確認するよう案内を追加

#### Safe モード

log-checker サブエージェント（subagent_type: log-checker）を起動し、デプロイ後の本番ログを確認する。

- **異常なし** → 成功を報告
- **異常あり** → エラー内容をユーザーに報告し、ロールバックを提案

追加で、プラットフォーム固有の確認:

**Heroku の場合:**
- ロールバック提案時は `heroku rollback` を使用
- ロールバック実行後、再度log-checkerでエラー解消を確認

**FTPデプロイの場合:**
- GitHub Actions の実行状況を確認するよう案内を追加

**その他 (GitHub, GitLab等):**
- `git log --oneline -3` で最新コミットを表示

## 禁止事項

- `git push --force` / `git push -f` は絶対に使わない
- `git add -A` / `git add .` は使わない
- `git reset --hard` は使わない
- git config の変更はしない
- `--no-verify` フラグは使わない
