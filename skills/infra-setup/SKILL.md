---
name: infra-setup
description: 本番インフラの初期セットアップ & 検証（DB・監視・エラー通知・ブランチ戦略）
tools: Read, Glob, Bash, Write, Edit, AskUserQuestion
user_invocable: true
model: haiku
---

# infra-setup（本番インフラ セットアップ & 検証）

本番運用の基盤をセットアップし、準備状況を検証する。

- **初回（セットアップモード）**: ARCHITECTURE.md を読み、運用基盤を実際にセットアップする
- **2回目以降（検証モード）**: セットアップ済みの項目が正しく動いているか検証する

---

## 0. モード判定

プロジェクトの `CLAUDE.md` を読む。

- `infra-setup: done` が**ない** → セットアップモードへ
- `infra-setup: done` が**ある** → 検証モードへ

---

## セットアップモード

### Step 0: ARCHITECTURE.md の読み込み

`docs/ARCHITECTURE.md` を読み込む。特に以下のセクションから運用方針を把握する:
- 技術スタック（言語・FW・ホスティング先）
- エラーハンドリング・監視（エラー通知ツール・ログ方針）
- 認証・権限設計

ARCHITECTURE.md がなければ「先に /draft-arch で設計を固めよう」と伝えて終了する。

### Step 1: DBバックアップ

AskUserQuestion で質問:

> 本番DBの自動バックアップは設定済みですか？

選択肢: 設定済み / まだ / DBを使っていない

**「まだ」の場合:**

ARCHITECTURE.md の技術スタックからDB種別とホスティング先を特定し、該当する手順を案内する：

- **Heroku Postgres**: `heroku pg:backups:schedule DATABASE_URL --at '04:00 Asia/Tokyo'` を案内
- **Railway**: 自動バックアップの有効化手順を案内
- **AWS RDS**: コンソールから自動バックアップ有効化の手順を案内
- **自前PostgreSQL**: `pg_dump` のcron設定例を提示
- **自前MySQL**: `mysqldump` のcron設定例を提示
- **SQLite**: ファイルコピーのcron設定例を提示
- **その他**: 一般的なバックアップ戦略を案内

案内後:
> 復元テスト（バックアップから実際に復元できるか）はやりましたか？

### Step 2: ブランチ戦略

`git branch -a` で現在のブランチ構成を確認する。

mainブランチ（またはmaster）のみの場合、AskUserQuestion で質問:

> 本番ブランチ（main）に直接プッシュしています。開発用ブランチを分けますか？

選択肢: 分ける / このままでいい

**「分ける」の場合:**
- `git checkout -b develop` を実行
- CLAUDE.md に `default-branch: develop` を記録
- 「今後は develop で開発し、本番反映時に main にマージする」と案内

**「このままでいい」の場合:**
- リスクを伝えた上でスキップ

### Step 3: エラーハンドリング・監視のセットアップ

ARCHITECTURE.md の「エラーハンドリング・監視」セクションを参照し、以下を順に実施する。

#### 3a. グローバルエラーハンドラ

プロジェクトのコードを Glob/Read で確認し、グローバルエラーハンドラが存在するか調べる。

**存在しない場合:**
ARCHITECTURE.md の方針と技術スタックに基づいて、グローバルエラーハンドラを生成する。

例:
- **Express**: `app.use((err, req, res, next) => { ... })` ミドルウェア
- **Rails**: `rescue_from` in ApplicationController
- **Next.js**: `pages/_error.js` or `app/error.tsx`

ユーザーに確認後、実装する。

#### 3b. エラー通知（Sentry等）

ARCHITECTURE.md で指定されたエラー通知ツールを確認する。

**Sentry の場合:**
1. SDKパッケージをインストール（`npm install @sentry/node` 等）
2. 初期化コードを生成してエントリポイントに追加
3. DSNの設定箇所を用意（環境変数 `SENTRY_DSN`）
4. 「Sentry のプロジェクトを作成して DSN を取得し、環境変数に設定してください」と案内
5. テスト送信コマンドを案内

**その他のツールの場合:**
ARCHITECTURE.md の指定に従い、同様にセットアップを支援する。

#### 3c. ヘルスチェックエンドポイント

プロジェクトに `/health` エンドポイントが存在するか確認する。

**存在しない場合:**
技術スタックに応じたヘルスチェックエンドポイントを生成する（DB接続確認を含む）。

#### 3d. 死活監視

AskUserQuestion で質問:

> 死活監視は設定済みですか？

選択肢: 設定済み / まだ / 本番公開していない

**「まだ」の場合:**
- UptimeRobot（無料、5分間隔）: https://uptimerobot.com でURLを登録する手順を案内

### Step 4: 完了

全項目の確認後、CLAUDE.md に以下を追記する:

```markdown
# 運用設定
infra-setup: done
infra-setup-items:
  db-backup: {設定済み|スキップ|不要}
  branch-strategy: {設定済み|スキップ}
  error-handler: {設定済み|スキップ}
  error-notification: {設定済み|スキップ}
  health-check: {設定済み|スキップ}
  uptime-monitor: {設定済み|スキップ|後で}
```

結果サマリーを報告する。例:

```
運用セットアップ完了:
✅ DBバックアップ: Heroku自動バックアップ設定済み
✅ ブランチ戦略: develop分離済み
✅ エラーハンドラ: Express globalエラーミドルウェア追加
✅ エラー通知: Sentry SDK導入済み（DSN設定待ち）
✅ ヘルスチェック: /health エンドポイント追加
⚠️ 死活監視: 後で設定予定
```

---

## 検証モード

`infra-setup: done` がある場合に実行。CLAUDE.md の `infra-setup-items` を読み、各項目を検証する。

### 検証内容

| 項目 | 検証方法 |
|------|----------|
| エラーハンドラ | Glob/Read でコードが存在するか確認 |
| エラー通知 | Sentry SDK がインストールされているか、初期化コードがあるか確認 |
| ヘルスチェック | `/health` エンドポイントのコードが存在するか確認 |
| ブランチ戦略 | `git branch -a` で確認 |
| DBバックアップ | ユーザーに現状を確認 |
| 死活監視 | ユーザーに現状を確認 |

### 検証結果

```
運用チェック:
✅ エラーハンドラ: 存在確認OK
✅ Sentry: SDK + 初期化コード確認OK
❌ ヘルスチェック: /health が見つからない → 再作成を提案
✅ ブランチ: develop ブランチあり
✅ DBバックアップ: 設定済み（ユーザー確認）
⚠️ 死活監視: 未設定 → UptimeRobot を案内
```

「スキップ」だった項目は「前回スキップしました。今回設定しますか？」と再提案する。
「❌」の項目はセットアップモードと同じ手順で修復を支援する。

---

## ルール

- ARCHITECTURE.md を必ず読み、プロジェクトの方針に合わせてセットアップする
- 案内は具体的に（コマンド例やURL付き）
- セットアップモードではコードの生成・編集を行う（エラーハンドラ、Sentry初期化、ヘルスチェック等）
- 実装前にユーザーに確認を取る（何を生成するか提示してから実行）
- 「後でやる」はフラグを `後で` として記録（検証モードで再提案される）
- 「不要」「このままでいい」は `スキップ` として記録
