---
name: ops-check
description: 本番運用の準備状況を診断（DBバックアップ・ブランチ戦略・監視）
tools: Read, Glob, Bash, AskUserQuestion
user_invocable: true
model: haiku
---

# ops-check（本番運用チェック）

本番運用の準備状況を診断する。初回デプロイ前に1回実行する。

---

## 0. スキップ判定

プロジェクトの `CLAUDE.md` を読み、`ops-check: done` が含まれていれば「運用チェック済みです」と報告して終了する。

---

## 1. DBバックアップ確認

AskUserQuestion で以下を質問:

> 本番DBの自動バックアップは設定済みですか？

選択肢: 設定済み / まだ / DBを使っていない

**「まだ」の場合:**

プロジェクトの構成（CLAUDE.md、docker-compose.yml、Gemfile、package.json等）からDB種別とホスティング先を推定し、該当する案内を出す：

- **Heroku Postgres**: `heroku pg:backups:schedule DATABASE_URL --at '04:00 Asia/Tokyo'` を案内
- **AWS RDS**: コンソールから自動バックアップ有効化の手順を案内
- **自前PostgreSQL**: `pg_dump` のcron設定例を提示
- **自前MySQL**: `mysqldump` のcron設定例を提示
- **SQLite**: ファイルコピーのcron設定例を提示
- **その他**: 一般的なバックアップ戦略を案内

案内後に確認:

> 復元テスト（バックアップから実際に復元できるか）はやりましたか？

---

## 2. ブランチ戦略確認

`git branch -a` で現在のブランチ構成を確認する。

mainブランチ（またはmaster）のみの場合、AskUserQuestion で質問:

> 本番ブランチ（main）に直接プッシュしています。開発用ブランチを分けますか？

選択肢: 分ける / このままでいい

**「分ける」の場合:**
- `git checkout -b develop` を実行
- CLAUDE.md に `default-branch: develop` を記録
- 「今後は develop で開発し、本番反映時に main にマージしてください」と案内

**「このままでいい」の場合:**
- リスク（本番に直接デプロイされること）を伝えた上でスキップ

---

## 3. 監視・アラート確認

AskUserQuestion で以下を質問:

> サイトが落ちた時に通知が来る仕組みはありますか？（死活監視）

選択肢: 設定済み / まだ / 本番公開していない

**「まだ」の場合:**

以下を順に案内する：

**死活監視（必須）:**
- UptimeRobot（無料、5分間隔）: https://uptimerobot.com でURLを登録するだけ
- またはプロジェクトにヘルスチェックエンドポイント `/health` がなければ作成を提案（提案のみ。実装はしない）

**エラー通知（推奨）:**
- Sentry（無料枠あり）: https://sentry.io
- プロジェクトの言語/FWに応じたSDKインストールコマンドを案内
- 「エラーが起きたらメール/Slack通知が来るようになります」と説明

---

## 4. 完了

全項目の確認後、CLAUDE.md に以下を追記する:

```markdown
# 運用設定
ops-check: done
```

結果サマリーを報告する。例:

```
運用チェック完了:
✅ DBバックアップ: 設定済み
✅ ブランチ戦略: develop分離済み
⚠️ 監視: 後で設定予定
```

---

## ルール

- 案内は具体的に（コマンド例やURL付き）
- 「後でやる」はフラグを記録しない（次回また案内される）
- 「不要」「このままでいい」は明示的にスキップとして扱い、フラグを記録
- このスキルはファイルの作成・編集をしない（CLAUDE.md への記録を除く）
- ヘルスチェックエンドポイントの作成は「提案」のみ。実装はしない
