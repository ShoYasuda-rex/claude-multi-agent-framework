---
name: infra-setup-guard
description: 守りのインフラセットアップ（DBバックアップ・ブランチ戦略・エラーハンドリング・監視）
tools: Read, Glob, Grep, Bash, Write, Edit, AskUserQuestion, Task
user_invocable: true
model: opus
---

# infra-setup-guard（Part A: 守りのインフラ）

DBバックアップ・ブランチ戦略・エラーハンドリング・監視をセットアップする。

---

## 前提チェック

プロジェクトの `CLAUDE.md` を読む。

- `infra-setup-progress: part0` が**ある** → 続行
- `infra-setup-progress: part0` が**ない** → 「先に `/infra-setup` を実行してください」と案内して終了

`docs/ARCHITECTURE.md` を読み込み、技術スタック・エラーハンドリング方針を把握する。

---

## Part A の独立チェックを並列実行

Step 1（DBバックアップ確認） + Step 2（ブランチ確認） + Step 3a（エラーハンドラ確認）は独立しているため、Task で並列に自動チェックを実行する。結果を集約した後、未設定の項目を順にセットアップする。

---

### Step 1: DBバックアップ

#### 1a. 現状を自動チェック

ホスティング先に応じたコマンドを**実行して**現状を確認する:

- **Heroku Postgres**: `heroku pg:backups:schedules` を実行してスケジュールの有無を確認
- **Railway**: `railway variables` でDB関連変数を確認
- **その他**: ユーザーに質問

#### 1b. 未設定の場合 → 設定を実行

**Heroku の場合:**
1. `heroku pg:backups:schedule DATABASE_URL --at '04:00 Asia/Tokyo'` を実行
2. `heroku pg:backups:schedules` で設定結果を確認表示
3. 復元テストの実施を推奨（`heroku pg:backups:capture` → `heroku pg:backups:url` で取得可能と案内）

**その他のホスティング:**
- AWS RDS / 自前PostgreSQL / MySQL / SQLite: 手順を案内し、可能な範囲でコマンド実行を支援

---

### Step 2: ブランチ戦略

`git branch -a` を**実行して**現在のブランチ構成を確認する。

mainブランチ（またはmaster）のみの場合、AskUserQuestion で質問:

> 本番ブランチに直接プッシュしています。開発用ブランチを分けますか？

選択肢: 分ける / このままでいい

**「分ける」の場合:**
- `git checkout -b develop` を実行
- CLAUDE.md に `default-branch: develop` を記録

**「このままでいい」の場合:**
- リスクを伝えた上でスキップ

---

### Step 3: エラーハンドリング・監視のセットアップ

ARCHITECTURE.md の「エラーハンドリング・監視」セクションを参照し、以下を順に実施する。

#### 3a. グローバルエラーハンドラ

Glob/Read で**自動チェック**:
- **Rails**: `ApplicationController` に `rescue_from` があるか確認
- **Express**: グローバルエラーミドルウェアがあるか確認
- **Next.js**: `error.tsx` / `_error.js` があるか確認

**存在しない場合:**
技術スタックに基づいてエラーハンドラを生成し、ユーザー確認後に書き込む。

#### 3b. エラー通知

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

#### 3c. ヘルスチェックエンドポイント

Glob/Grep で `/health` または `/up` エンドポイントが存在するか**自動チェック**する。

**存在しない場合:**
技術スタックに応じたヘルスチェックエンドポイントを生成（DB接続確認含む）し、ユーザー確認後に書き込む。

**存在する場合:**
本番URLに対して `curl` でヘルスチェックを**実行して**応答を確認する（URLがわかる場合）。

#### 3d. 死活監視

AskUserQuestion で質問:

> 死活監視は設定済みですか？

選択肢: 設定済み / まだ / 本番公開していない

**「まだ」の場合:**
- UptimeRobot（無料、5分間隔）の登録手順を案内

---

### Part A 完了: CLAUDE.md に記録

CLAUDE.md の `infra-setup-progress` を `partA` に更新し、Part A の項目を追記する:

```markdown
infra-setup-progress: partA
infra-setup-items:
  ...（既存の Part 0 項目）...
  # Part A: 守りのインフラ
  db-backup: {設定済み|スキップ|不要}
  branch-strategy: {設定済み|スキップ}
  error-handler: {設定済み|スキップ}
  error-notification: {設定済み|スキップ}
  health-check: {設定済み|スキップ}
  uptime-monitor: {設定済み|スキップ|後で}
```

ユーザーに以下を案内する:

> Part A（守りのインフラ）が完了しました。
> 次は `/infra-setup-connect` を実行してください（本番接続: デプロイ・環境変数・外部サービス・ドメイン・DB・スモークテスト）。

---

## ルール

- **確認・診断系コマンドは即実行する**（案内ではなく実行結果を見せる）
- **変更・設定系コマンドはユーザー確認後に実行する**（案内だけで終わらせない）
- AskUserQuestion は判断が必要な分岐点でのみ使う
- セットアップモードではコードの生成・編集を行う（エラーハンドラ、通知初期化、ヘルスチェック等）
- 外部サービスのAPIキー・シークレットは絶対にコードにハードコードしない（環境変数を案内する）
- 「後でやる」は `後で` として記録、「不要」「このままでいい」は `スキップ` として記録

### UI操作の案内ルール

CLIで完結しない操作は、**ステップ番号付きの具体的な手順**で案内する:
- 各ステップは1アクション（クリック or 入力）
- ボタン名・メニュー名は画面の表記そのままを使う
- 入力値が決まっているものはバッククォートで具体的に提示
- 手順の最後に「次のアクション」を明示する
