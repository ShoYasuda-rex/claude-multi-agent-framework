---
name: deploy
description: add・commit・pushを実行。「/deploy」で即実行、「/deploy safe」で本番設定チェック+安全デプロイ
model: opus
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
- **リモートが存在しない** → 「`/infra` を先に実行してください」と案内して終了

---

### 2. デプロイ設定を確認する

CLAUDE.md の Git 運用セクションに「FTP」「GitHub Actions」「deploy.yml」のいずれかが含まれているか確認する。

**含まれていない** → ステップ 3 へスキップ（FTP不要のプロジェクト）

**含まれている（FTPデプロイが必要）** → `.github/workflows/deploy.yml` が存在するか Glob で確認する:

- **存在する** → ステップ 3 へ
- **存在しない** → 「`/infra` を先に実行してください（FTPデプロイのワークフロー生成が必要です）」と案内して終了

---

### 3. learned.md チェック

プロジェクトの `rules/learned.md` が存在する場合、デプロイ関連エントリ（Heroku, Railway, deploy, push, port, dyno, worker 等のキーワード）を確認し、該当するパターンがあれば事前にチェックすること。

### 4. 状態確認（並列実行）

以下を並列で実行:

- `git status` — 変更ファイルの確認
- `git branch --show-current` — 現在のブランチ名
- `git remote -v` — リモートの確認
- `git log --oneline -5` — 直近コミット（メッセージスタイル確認用）

変更がなければ「変更なし」と報告して終了。

### 5. DB スキーマ変更チェック（Quick / Safe 共通）

**両モードで必ず実行する。** ステップ 4 の `git status` 結果を参照し、以下を確認:

#### 4a. 破壊的マイグレーション検知

マイグレーションファイル（`*.sql`, `db/migrate/*.rb`, `prisma/migrations/**`, `migrations/**` 等）が変更に含まれる場合、その内容を Grep で以下のパターンでスキャンする:

- `DROP COLUMN` / `DROP TABLE` / `RENAME COLUMN` / `RENAME TABLE`
- `remove_column` / `drop_table` / `rename_column` / `rename_table`（Rails）
- `dropColumn` / `dropTable` / `renameColumn` / `renameTable`（Prisma/Knex等）

**検知した場合** → デプロイを停止し、ユーザーに警告:
> ⚠️ 破壊的マイグレーションが含まれています。該当データは削除され復元できません。
> - {検知した操作の一覧}
> 本当に続行しますか？

ユーザーが承認 → 次のステップへ
ユーザーが拒否 → 処理を中止

#### 4b. スキーマ変更の通知

破壊的でないスキーマ変更（カラム追加等）が含まれる場合、**ユーザーに警告して確認を取る**:
- 「DB スキーマ変更が含まれています。本番DBへのマイグレーションが別途必要です。続行しますか？」
- ユーザーが承認 → 次のステップへ
- ユーザーが拒否 → 処理を中止

### 6. 【Safe モードのみ】安全バリデーション

**Quick モードではこのステップをスキップする。**

以下のいずれかに該当する場合、**ユーザーに警告して確認を取る**:

- **保護ブランチ**: `main` / `master` / `production` ブランチへの直接プッシュ
- **機密ファイル**: `.env`, `credentials`, `secret`, `*.pem`, `*.key` などがステージング対象に含まれる場合
- **変更なし**: 未コミットの変更も未プッシュのコミットもない場合 → 処理を中止（未プッシュのコミットがある場合はステップ 9 へスキップ）
- **環境変数追加**: diff 内に新しい `env.` 参照（`env.XXXX` や `process.env.XXXX`）が追加されている場合、本番環境への設定漏れがないか確認を促す
- **インフラ依存変更**: diff の内容から「本番インフラ側の準備が必要な変更」が含まれていないかをAIが判断する。該当する場合、本番のインフラ状態を実際にコマンドで確認し、不足があればユーザーに警告する

### 7. 【Safe モードのみ】差分の確認

**Quick モードではこのステップをスキップする。**

- `git diff` と `git diff --cached` で変更内容を確認する
- 変更ファイルの一覧と概要をユーザーに表示する

### 8. add & commit

- 変更ファイルを個別に `git add <file>` でステージング（`git add -A` / `git add .` は使わない）
- 以下に該当するファイルは **ステージングしない** 。`.gitignore` に未登録なら追記して恒久的にブロックする:
  - **機密ファイル**: `.env`, `credentials`, `*.key`, `*.pem`, `secret*` 等
  - **不要ファイル**: ツールキャッシュ・ログ・生成物（例: `.playwright-mcp/`, `.ruff_cache/`, `*.log`, `dist/`, `node_modules/`, `__pycache__/` 等）
- 判断基準: 実行環境やツールが自動生成するもので、リポジトリに含める必要がないもの
- 変更内容からコミットメッセージを自動生成し、確認なしでコミットする
- HEREDOC 形式で渡す:

```
git commit -m "$(cat <<'EOF'
コミットメッセージ

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

### 9. 【Safe モードのみ】リモートとの同期チェック

**Quick モードではこのステップをスキップする。**

- `git fetch` でリモートの最新状態を取得
- `git status` でリモートとの差分を確認
- コンフリクトがある場合はユーザーに報告して指示を仰ぐ

### 10. 【Safe モードのみ】本番設定チェック（pre-deploy）

**Quick モードではこのステップをスキップする。**

release-checker サブエージェント（subagent_type: release-checker）を起動し、`phase: pre-deploy` で以下をチェック:

- 環境変数の過不足（コード vs 本番）
- 外部サービスの設定漏れ
- マイグレーションの未実行

❌ がある場合はユーザーに警告し、続行するか確認する。

### 11. push

- CLAUDE.md の設定に従ってプッシュを実行: `git push {remote} {branch}`
  - 例: `git push origin master`, `git push heroku master`
- 失敗した場合はエラー内容を報告

### 12. GitHub Actions ログ確認（Quick / Safe 共通）

プッシュ先が GitHub（リモート: `origin`）の場合、**両モードで必ず実行する。**

1. `gh run list --limit 1 --json status,conclusion,name,databaseId,headBranch` で最新のワークフロー実行を取得
2. push 直後はまだ run が開始していない場合があるので、最新 run の `headBranch` が現在のブランチと一致するまで最大30秒（5秒間隔）待つ
3. 該当 run を検出したら `status` を確認:
   - **`in_progress` / `queued`** → `gh run watch {run_id}` で完了まで待機する
   - **`completed`** → 次へ
4. `conclusion` を確認:
   - **`success`** → ステップ 12 へ
   - **`failure`** → `gh run view {run_id} --log-failed` でエラーログを取得し、ユーザーに表示する。修正を提案する
   - **`cancelled`** → キャンセルされた旨を報告

`gh` コマンドが使えない場合（未インストール等）は、GitHub Actions のURLを案内してスキップする。

### 13. 完了報告

#### Quick モード
- ブランチ名、コミット内容、プッシュ先、Actions結果を1行で報告

#### Safe モード

以下を並列実行:

1. **release-checker（post-deploy）**: サブエージェント（subagent_type: release-checker）を `phase: post-deploy` で起動し、スモークテスト（ヘルスチェック・トップページ応答・SSL証明書）を実行する
2. **log-checker**: サブエージェント（subagent_type: log-checker）を起動し、デプロイ後の本番ログを確認する
3. **プロセス稼働確認**: Procfile で定義された全プロセスが本番で実際に稼働しているか確認する（例: Heroku なら `heroku ps`）。未起動のプロセスがあればユーザーに警告する

- **両方異常なし** → 成功を報告
- **異常あり** → エラー内容をユーザーに報告し、ロールバックを提案

追加で、プラットフォーム固有の確認:

**Heroku の場合:**
- ロールバック提案時は `heroku rollback` を使用
- ロールバック実行後、再度log-checkerでエラー解消を確認

**その他 (GitHub, GitLab等):**
- `git log --oneline -3` で最新コミットを表示

## 禁止事項

- `git push --force` / `git push -f` は絶対に使わない
- `git add -A` / `git add .` は使わない
- `git reset --hard` は使わない
- git config の変更はしない
- `--no-verify` フラグは使わない
