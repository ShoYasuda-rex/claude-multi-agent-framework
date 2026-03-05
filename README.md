# Claude Code マルチエージェント開発フロー

個人開発で、品質を保ちながら高速開発するためのフレームワーク。

- 1人でチーム相当の開発品質を実現する
- 品質はエージェントによる静的検証・動的検証・テストで担保する
- 人間は「決める」。AIは「作る・調べる・検証する・報告する」

> **思想**: 要件は変わる。だから仕様は固めない。
> CORE.md で「なぜ作るか」、ARCHITECTURE.md で「どう作るか」を書き、動くものから育てる。

## 開発フロー

```
【設計】 /kickoff → CORE.md + ARCHITECTURE.md + プロジェクト初期化
【デザイン】 /mockup → 代表1画面でデザイン確定 → そのまま実装
【実装】 /parallel → タスク分割 → サブエージェントが並列実装
【検証】 /verify → 静的検証・動的検証・テストを選択して並列実行
【監査】 /audit → コード・セキュリティ・設計・法令を一括監査
【デプロイ】 /deploy → add → commit → push

【初回リリース】
/infra-setup → /release-setup → /audit → /deploy

【育てるサイクル】
実装 → /verify → /deploy → 繰り返し
```

迷ったら `/solo-trainer` と打てば、プロジェクトの状態を見て次にやることを教えてくれる。

## コマンド一覧

### 毎回使う

| コマンド | 概要 |
|---------|------|
| `/local` | ローカルサーバーを起動してブラウザで開く |
| `/verify` | 品質チェック（静的検証・動的検証・テストを選択して並列実行） |
| `/deploy` | git add → commit → push。`/deploy safe` で安全モード |

### 設計・初期構築

| コマンド | 概要 |
|---------|------|
| `/kickoff` | 対話で CORE.md + ARCHITECTURE.md を作成 + プロジェクト初期化 |
| `/mockup` | 代表1画面でデザイン決め → 確定後そのまま実装 |
| `/infra-setup` | 本番の箱を作る（Git・GitHub・プラットフォーム・デプロイ設定・ドメイン・DB・監視） |
| `/release-setup` | 本番の中身を整える（環境変数・外部サービス・DB・スモークテスト） |

### 並列実行・調査・監査

| コマンド | 概要 |
|---------|------|
| `/parallel` | タスク分割 → サブエージェントが worktree で並列実装 |
| `/research-team` | UX・ユーザー・競合・再構想・ビジュアルの5視点で並列調査 |
| `/audit` | 監査（コード・セキュリティ・設計・法令）を選択して並列実行 |

### アセット・ユーティリティ

| コマンド | 概要 |
|---------|------|
| `/get-web-sounds` | フリーBGM・SEの調査→比較試聴→取得→配置→クレジット管理 |
| `/gen-ai-pixels` | ローカルFLUX.1サーバーでドット絵アセットをバッチ生成・配置・クレジット管理 |
| `/backup` | 現在の状態を git コミットで保存（push しない） |
| `/rollback` | 直近コミットから復元先を選択 |
| `/gen-arch` | コード実態からアーキテクチャドキュメントを自動生成 |

### 学習

| コマンド | 概要 |
|---------|------|
| `/feature-trainer` | フロントエンドだけで小さなプロダクトを1日で作り切る（入門） |
| `/fullstack-trainer` | DB+API+Workers でフルスタックプロダクトを2日で作り切る（中級） |
| `/solo-trainer` | 自走で開発を回す練習。次の1手を指示するトレーナー（実践） |

## セットアップ

```
~/.claude/
├── agents/           # エージェント定義（8種）
│   ├── code-checker.md
│   ├── visual-checker.md
│   ├── test-checker.md
│   ├── audit-code-checker.md
│   ├── audit-security-checker.md
│   ├── audit-architecture-checker.md
│   ├── audit-law-checker.md
│   └── log-checker.md
├── skills/           # スキル定義（18種）
│   ├── kickoff/        mockup/        local/
│   ├── parallel/       verify/        audit/
│   ├── deploy/         backup/        rollback/
│   ├── infra-setup/    release-setup/
│   ├── research-team/  gen-arch/      get-web-sounds/  gen-ai-pixels/
│   ├── feature-trainer/  fullstack-trainer/  solo-trainer/
├── docs/             # フロー詳細ドキュメント
├── CLAUDE.md         # 共通ルール
└── settings.json
```

**必要なもの**: Claude Code + Playwright（動的検証で使用）

詳細は [docs/マルチエージェント開発フロー.md](docs/マルチエージェント開発フロー.md) を参照。

## ライセンス

MIT
