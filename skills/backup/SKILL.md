---
name: backup
description: gitローカルコミット（pushなし）
model: haiku
user-invocable: true
---

# Backup（ローカルコミット）

プロジェクトの現状をgitにコミットする。プッシュはしない。

---

## 手順

### 1. CLAUDE.md 更新チェック

- プロジェクトの `CLAUDE.md` を確認
- 直近の変更が構造・設計に関わるものであれば、CLAUDE.md に反映
- 変更があれば更新してからコミットに含める

### 2. git 初期化チェック

- `.git` がなければ「`/infra` を先に実行してください」と案内して終了

### 3. `.gitignore` の存在チェック

- `.gitignore` がなければ「`/infra` を先に実行してください」と案内して終了

### 4. 機密除外 + ステージング

`~/.claude/scripts/git-safe-add.sh` を実行する（機密・不要ファイルの除外 + 個別git add + .gitignore自動更新）。

- `NO_CHANGES=true` → 「コミットするものがありません」と報告して終了
- `EXCLUDED=...` → 除外されたファイルを確認（機密ファイルがあればユーザーに警告）
- スクリプトが存在しない・実行エラーの場合はスクリプトの内容を確認して修正する

### 6. コミット

- `git diff --staged` で変更内容を確認
- 変更がなければ「コミットするものがありません」と報告して終了
- 変更内容に基づいて適切なコミットメッセージを自動生成
- HEREDOC 形式でコミット:

```
git commit -m "$(cat <<'EOF'
コミットメッセージ

Co-Authored-By: Claude <noreply@anthropic.com>
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
