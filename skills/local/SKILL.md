---
name: local
description: ローカル開発サーバーを起動してブラウザで開く
model: haiku
tools: Bash, Read, Glob, mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_snapshot, mcp__plugin_playwright_playwright__browser_fill_form, mcp__plugin_playwright_playwright__browser_click
user_invocable: true
---

# ローカル開発サーバー起動

プロジェクトの CLAUDE.md から開発コマンドを読み取り、サーバーを起動してブラウザで開く。

---

## 手順

### 1. 開発コマンドの特定

- プロジェクトの CLAUDE.md（カレントディレクトリの `CLAUDE.md`）を Read で読む
- 「開発コマンド」「ローカル開発」「dev」等のセクションから起動コマンドを特定する
- コマンドからデフォルトポート番号も特定する

#### CLAUDE.md に記載がある場合
- **ただし `docker-compose.yml` が存在するなら**、記載コマンドがDocker経由か確認する
- Docker記載がなければユーザーに確認:「docker compose で起動しますか？」
- Dockerを使う場合 → CLAUDE.mdの開発コマンドセクションを更新してからステップ2へ

#### CLAUDE.md に記載がない場合
以下の優先順で自動検出する:
  1. `docker-compose.yml` があれば `docker compose up -d`（ポート: compose設定から取得）
  2. `package.json` があれば `npm run dev` または `npm start`
  3. `Gemfile` があれば `bundle exec rails s`
  4. `manage.py` があれば `python manage.py runserver`
  5. 見つからなければユーザーに聞く

- 検出結果をユーザーに確認後、**CLAUDE.mdの開発コマンドセクションに記載する**（次回以降のために）

### 2. ポート競合チェック（重要）

サーバー起動前に、対象ポートが既に使用中でないか確認する。

- Windows: `netstat -ano | findstr "LISTENING" | findstr ":{port}"` でポート使用状況を確認
- Mac/Linux: `lsof -i :{port}` でポート使用状況を確認
- **ポートが空いている場合** → ステップ3へ進む
- **ポートが使用中の場合** → 以下を実行:
  1. LISTENINGの結果から**重複を除いた全PIDを抽出**する（同じポートに複数プロセスが存在する場合がある）
  2. 各PIDについてプロセス情報を取得する:
     - Windows: `wmic process where ProcessId={pid} get CommandLine //FORMAT:LIST` でコマンドラインを取得
     - Mac/Linux: `ps -p {pid} -o comm=,args=` でプロセス名とコマンドを取得
  3. 取得した全プロセスの情報をユーザーにまとめて提示し、選択肢を出す:
     - 「全プロセスを終了して同じポートで起動する」（推奨）
     - 「別のポート（{port+1}）で起動する」
     - 「キャンセル」
  4. **終了する場合は、対象ポートの全PIDを `taskkill //PID {pid} //F`（Windows）/ `kill {pid}`（Mac/Linux）で終了する**
  5. 終了後、`netstat`/`lsof` で**ポートが完全に解放されたことを確認してから**ステップ3へ進む（解放されていなければ1秒待って再確認、最大3回リトライ）

### 3. サーバー起動

- **Docker の場合:** `docker compose up -d` を実行（バックグラウンド不要、detachedモードで起動）
- **それ以外:** 特定したコマンドを Bash でバックグラウンド実行する（`run_in_background: true`）
- 起動ログからポート番号を検出する
- **ビルド/起動がエラーで失敗した場合** → ステップ3.5 のトラブルシューティングへ

### 3.5. トラブルシューティング（起動失敗時のみ）

起動コマンドがエラーで失敗した場合、エラーメッセージから原因を判別し**自動修正を試みる**。修正後、ステップ3に戻って再起動する。最大2回まで自動修正を試み、それでも失敗したらユーザーに報告する。

よくあるエラーと自動修正パターン:

| エラーパターン | 原因 | 自動修正 |
|--|--|--|
| `Gemfile.lock: not found`（Docker ビルド） | ロックファイル未生成 | Dockerfile の `COPY Gemfile Gemfile.lock ./` → `COPY Gemfile Gemfile.lock* ./` に修正 |
| `package-lock.json: not found`（Docker ビルド） | ロックファイル未生成 | 同上（`COPY package.json package-lock.json* ./`） |
| ソケット接続エラー（`/var/run/postgresql/.s.PGSQL.5432`） | database.yml が Docker ネットワーク未対応 | docker-compose.yml の environment を確認し、database.yml に `host: <%= ENV.fetch("DATABASE_HOST", "localhost") %>` 等を追加 |
| `database "xxx" does not exist` | DB 未作成 | Docker: `docker compose run --rm web bin/rails db:create db:migrate` / 非Docker: `bin/rails db:create db:migrate` |
| `Migrations are pending` | マイグレーション未実行 | Docker: `docker compose run --rm web bin/rails db:migrate` / 非Docker: `bin/rails db:migrate` |
| `Module not found` / `Cannot find module` | node_modules 未インストール | `npm install` |
| `Could not find gem` / `bundle install` 要求 | gem 未インストール | Docker: `docker compose run --rm web bundle install` / 非Docker: `bundle install` |

上記に該当しないエラーの場合は、エラーログを表示してユーザーに報告する。

### 4. 起動確認

- サーバーが正しく起動したか検証する（起動後2秒待ってからポートの LISTEN 状態を確認）
- **起動失敗の場合**（ポートが開いていない）→ `docker compose logs` 等で起動ログを確認し、ステップ3.5 のパターンに該当すればトラブルシューティングへ。該当しなければユーザーに報告
- **起動成功の場合** → ステップ5へ

### 5. ブラウザで開く

- `browser_navigate` で `http://localhost:{port}` を開く
- ナビゲーション失敗（`net::ERR_EMPTY_RESPONSE` 等）の場合 → 3秒待って1回だけリトライ

### 6. 自動ログイン（ログイン画面の場合）

- `browser_snapshot` でページの状態を確認する
- **ログインフォームが表示されている場合**（メールアドレス/パスワードの入力欄がある）:
  1. CLAUDE.md の「開発コマンド」セクションからテスト用認証情報を探す（例: `admin@example.com / password`、`db:seed` のコメント等）
  2. 認証情報が見つかった場合 → `browser_fill_form` でメールアドレスとパスワードを入力し、`browser_click` でログインボタンをクリック
  3. 認証情報が見つからない場合 → 「ログインフォームが表示されています。認証情報を入力してください。」と報告して終了
- **ログインフォームでない場合** → そのままステップ7へ

### 7. 完了報告

- 「サーバー起動しました: http://localhost:{port}」と1行表示して終了
