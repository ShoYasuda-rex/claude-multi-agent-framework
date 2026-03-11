---
name: deploy
description: add・commit・pushを実行。「/deploy」で即実行、「/deploy safe」で本番設定チェック+安全デプロイ
model: opus
user-invocable: true
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

### 6〜7. 【Safe モードのみ】安全バリデーション + 差分確認

**Quick モードではスキップ。** Safe モードの場合、`~/.claude/skills/deploy/references/safe.md` を Read で読み込み、Steps 6〜7 に従って実行する。

### 8. add & commit

- `~/.claude/scripts/git-safe-add.sh` を実行する（機密・不要ファイルの除外 + 個別git add + .gitignore自動更新）
  - `NO_CHANGES=true` → 「変更なし」と報告して終了
  - `EXCLUDED=...` → 除外されたファイルを確認（機密ファイルがあればユーザーに警告）
  - スクリプトが存在しない・実行エラーの場合はスクリプトの内容を確認して修正する
- 変更内容からコミットメッセージを自動生成し、確認なしでコミットする
- HEREDOC 形式で渡す:

```
git commit -m "$(cat <<'EOF'
コミットメッセージ

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### 9〜10. 【Safe モードのみ】同期チェック + 本番設定チェック

**Quick モードではスキップ。** Safe モードの場合、`~/.claude/skills/deploy/references/safe.md` を Read で読み込み、Steps 9〜10 に従って実行する。

### 11. push

- CLAUDE.md の設定に従ってプッシュを実行: `git push {remote} {branch}`
  - 例: `git push origin master`, `git push heroku master`
- 失敗した場合はエラー内容を報告

### 12. GitHub Actions ログ確認（Quick / Safe 共通）

プッシュ先が GitHub（リモート: `origin`）の場合、**両モードで必ず実行する。**

`~/.claude/skills/deploy/scripts/gh-actions-wait.sh {branch}` を実行する。

結果に応じた対応:
- **`CONCLUSION=success`** → ステップ 13 へ
- **`CONCLUSION=failure`** → `---FAILED_LOG---` 以降のエラーログをユーザーに表示し、修正を提案する
- **`CONCLUSION=cancelled`** → キャンセルされた旨を報告
- **`STATUS=no_gh_cli`** / **`STATUS=not_authenticated`** → MESSAGE の内容を案内してスキップ
- **`STATUS=no_run_found`** → ワークフロー未検出の旨を報告してスキップ
- スクリプトが存在しない・実行エラーの場合はスクリプトの内容を確認して修正する

### 13. 完了報告

#### Quick モード
- ブランチ名、コミット内容、プッシュ先、Actions結果を1行で報告

#### Safe モード
`~/.claude/skills/deploy/references/safe.md` を Read で読み込み、Step 13 に従って実行する。

## 禁止事項

- `git push --force` / `git push -f` は絶対に使わない
- `git add -A` / `git add .` は使わない
- `git reset --hard` は使わない
- git config の変更はしない
- `--no-verify` フラグは使わない
