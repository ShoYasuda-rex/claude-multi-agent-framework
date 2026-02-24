---
name: backup
description: gitローカルコミット（pushなし）
model: haiku
user_invocable: true
disable-model-invocation: true
---

# Backup（ローカルコミット）

プロジェクトの現状をgitにコミットする。プッシュはしない。

---

## 手順

### 0. CLAUDE.md 初期生成チェック

- プロジェクトルートに `CLAUDE.md` が存在しない場合、`/init` スキルを実行して生成する
- 既に存在する場合はスキップし、ステップ1に進む

### 1. CLAUDE.md 更新チェック

- プロジェクトの `CLAUDE.md` を確認
- 直近の変更が構造・設計に関わるものであれば、CLAUDE.md に反映
- 変更があれば更新してからコミットに含める

### 2. git 初期化チェック

- `.git` がなければ `git init` を実行

### 2.5. dependabot.yml の確認・生成

- `.github/dependabot.yml` が存在しなければ作成:
  - `mkdir -p .github`
  - プロジェクトの技術スタックを探索し、該当する `package-ecosystem` を自動判定:
    - `Gemfile` → `bundler`
    - `package.json` → `npm`
    - `composer.json` → `composer`
    - `requirements.txt` / `Pipfile` → `pip`
    - `go.mod` → `gomod`
    - `Dockerfile` → `docker`
    - `pom.xml` / `build.gradle` → `maven` / `gradle`
    - `.github/workflows/` → `github-actions`
  - 検出されたエコシステムごとに `updates` エントリを生成（schedule: weekly）

### 3. `.gitignore` の確認・補完

- プロジェクトを探索し、以下を確認:
  - 機密ファイル（`.env`, `.dev.vars`, `*_key*`, `credentials.*` など）
  - 依存関係（`node_modules/`, `vendor/`, `venv/`, `__pycache__/` など）
  - ビルド成果物（`dist/`, `build/`, `*.min.js` など）
  - OS/エディタファイル（`.DS_Store`, `Thumbs.db`, `.vscode/`, `.idea/` など）
  - ログ・一時ファイル（`*.log`, `*.tmp`, `*.bak` など）
- 不足があれば `.gitignore` に追加

### 4. 機密ファイルチェック

- `git status` で変更ファイル一覧を取得
- 以下のパターンに該当するファイルがあれば **ステージングから除外し、ユーザーに警告**:
  - `.env`, `.dev.vars`, `*.pem`, `*.key`, `credentials.*`, `secret*`

### 5. ステージング

- 変更ファイルを個別に `git add <file>` でステージングする（`git add -A` や `git add .` は使わない）

### 6. コミット

- `git diff --staged` で変更内容を確認
- 変更がなければ「コミットするものがありません」と報告して終了
- 変更内容に基づいて適切なコミットメッセージを自動生成
- HEREDOC 形式でコミット:

```
git commit -m "$(cat <<'EOF'
コミットメッセージ

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

### 7. 完了報告

- コミット内容のサマリーを報告

---

## 禁止事項

- `git add -A` / `git add .` は使わない
- `git push` はしない（プッシュは /safe-deploy で行う）
- 機密ファイルをコミットしない
