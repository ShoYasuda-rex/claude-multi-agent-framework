---
name: infra-setup
description: 本番インフラの初期セットアップ（モード判定・Git初期化・GitHub作成・プラットフォーム作成）& 全項目検証
tools: Read, Glob, Grep, Bash, Write, Edit, AskUserQuestion, Task
user_invocable: true
model: opus
---

# infra-setup（モード判定 + Part 0 + 検証）

本番運用の基盤をセットアップし、準備状況を検証する。

- **初回（セットアップモード）**: ARCHITECTURE.md を読み、Part 0（リポジトリ & プラットフォーム）をセットアップ → 次のスキルを案内
- **2回目以降（検証モード）**: セットアップ済みの全項目が正しく動いているか検証する

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
- API設計（外部サービス依存）

ARCHITECTURE.md がなければ「先に /draft で設計を固めよう」と伝えて終了する。

---

### 【Part 0: リポジトリ & プラットフォーム】

以下を順に確認し、未セットアップなら実行する。既に完了している項目はスキップ。

### Step 0.1: Git初期化

`.git` ディレクトリの存在を確認する。

- **存在する** → スキップ
- **存在しない** → `git init` を実行

### Step 0.2: GitHubリポジトリ作成

`git remote -v` を**実行して**リモートの有無を確認する。

- **リモートが存在する** → スキップ
- **リモートが存在しない** → 以下を実行:
  1. `.gitignore` を確認・補完（機密ファイル・依存関係・ビルド成果物・OS/エディタファイル）
  2. `gh repo create {プロジェクト名} --private --source=. --remote=origin` を実行
     - `gh` CLI が使えない場合はユーザーに手動作成を依頼
  3. 初期コミット: 現在のファイルを個別に `git add` & commit
  4. 初期プッシュ: `git push -u origin master`

### Step 0.3: デプロイプラットフォーム作成

ARCHITECTURE.md の技術スタック（ホスティング先）に応じて、プラットフォームの存在を確認し、なければ作成する。

| ホスティング先 | 存在確認 | 作成コマンド |
|--------------|----------|------------|
| Cloudflare Pages | `npx wrangler pages project list` で確認 | `npx wrangler pages project create {プロジェクト名}` → GitHub連携 |
| Heroku | `heroku apps:info` で確認 | `heroku create {プロジェクト名}` → `git remote add heroku ...` |
| Railway | `railway status` で確認 | `railway init` → GitHub連携 |
| Vercel | `vercel ls` で確認 | `vercel` → GitHub連携 |
| その他 | ARCHITECTURE.md の指定に従う | ユーザーに確認しながら実行 |

各ステップで失敗したら修正を試み、ダメならユーザーに報告して判断を仰ぐ。

---

### Part 0 完了: CLAUDE.md に記録

CLAUDE.md に以下を追記する:

```markdown
# 運用設定
infra-setup-progress: part0
infra-setup-items:
  # Part 0: リポジトリ & プラットフォーム
  git-repo: {設定済み|既存}
  github-remote: {設定済み|既存}
  deploy-platform: {設定済み|既存|不要}
```

ユーザーに以下を案内する:

> Part 0（リポジトリ & プラットフォーム）が完了しました。
> 次は `/infra-setup-guard` を実行してください（守りのインフラ: DBバックアップ・ブランチ戦略・エラー監視）。

---

## 検証モード

`infra-setup: done` がある場合に実行。CLAUDE.md の `infra-setup-items` を読み、各項目を**コマンド実行で**検証する。

独立したチェックは Task で並列実行する:
- Part 0（Git・GitHub・プラットフォーム） + Part A（DB・ブランチ・エラー） + Part B（デプロイ・環境変数・外部サービス）

### 検証内容

| 項目 | 検証方法 |
|------|----------|
| **Part 0: リポジトリ & プラットフォーム** | |
| Gitリポジトリ | `.git` 存在確認 |
| GitHubリモート | `git remote -v` で確認 |
| デプロイプラットフォーム | ホスティング先CLIで存在・接続確認 |
| **Part A: 守りのインフラ** | |
| DBバックアップ | `heroku pg:backups:schedules` 等を実行して確認 |
| ブランチ戦略 | `git branch -a` を実行して確認 |
| エラーハンドラ | Glob/Read でコードが存在するか確認 |
| エラー通知 | Gemfile/package.json でSDKの存在 + 初期化コード確認 |
| ヘルスチェック | コード確認 + `curl` で本番エンドポイントを実行確認 |
| 死活監視 | ユーザーに現状を確認 |
| **Part B: 本番接続** | |
| デプロイ設定 | Procfile/Dockerfile 等の存在を Glob で確認 |
| 環境変数 | コードから再収集 → `heroku config` 等を実行して過不足照合 |
| 外部サービス | 環境変数の存在をホスティング先の config で自動判定 |
| ドメイン・SSL | `heroku domains` 等を実行して確認 |
| 本番DB | `heroku run rails db:migrate:status` 等を実行して確認 |
| スモークテスト | `curl` で本番URL応答を実行確認 |

### 検証結果の表示形式

```
運用チェック:

【Part 0: リポジトリ & プラットフォーム】
✅ Gitリポジトリ: .git 確認OK
✅ GitHubリモート: origin → github.com/...
✅ デプロイプラットフォーム: Heroku app 確認OK

【Part A: 守りのインフラ】
✅ DBバックアップ: スケジュール確認OK（毎日04:00 JST）
✅ ブランチ: develop ブランチあり
✅ エラーハンドラ: rescue_from 確認OK
✅ エラー通知: sentry-rails gem + 初期化コード確認OK
✅ ヘルスチェック: /up → 200 OK
⚠️ 死活監視: 未設定

【Part B: 本番接続】
✅ デプロイ設定: Procfile 確認OK
⚠️ 環境変数: DEEPL_API_KEY がコードに追加されたが本番に未設定
✅ 外部サービス: Twilio/DeepL の環境変数確認OK
✅ ドメイン・SSL: example.herokuapp.com
✅ 本番DB: 未実行マイグレーションなし
✅ スモークテスト: 全エンドポイント応答OK
```

「スキップ」だった項目は「前回スキップしました。今回設定しますか？」と再提案する。
「❌」の項目はセットアップモードと同じ手順で修復を実行する。
「⚠️」の項目は差分や変更点を具体的に示し、修正コマンドを提示・実行する。

---

## ルール

- ARCHITECTURE.md を必ず読み、プロジェクトの方針に合わせてセットアップする
- **確認・診断系コマンドは即実行する**（案内ではなく実行結果を見せる）
- **変更・設定系コマンドはユーザー確認後に実行する**（案内だけで終わらせない）
- AskUserQuestion は判断が必要な分岐点でのみ使う
- 外部サービスのAPIキー・シークレットは絶対にコードにハードコードしない（環境変数を案内する）
- 本番への破壊的操作（DB変更、force push等）は必ずユーザー確認を取る
- 「後でやる」は `後で` として記録（検証モードで再提案される）
- 「不要」「このままでいい」は `スキップ` として記録

### UI操作の案内ルール

CLIで完結しない操作は、**ステップ番号付きの具体的な手順**で案内する:
- 各ステップは1アクション（クリック or 入力）
- ボタン名・メニュー名は画面の表記そのままを使う
- 入力値が決まっているものはバッククォートで具体的に提示
- 手順の最後に「次のアクション」を明示する
