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
【デザイン】 /design → 5+パターンで比較 → 確定 → そのまま実装
【実装】 /parallel → タスク分割 → サブエージェントが並列実装
【検証】 /verify → 静的検証・動的検証・テストを選択して並列実行
【監査】 /audit → コード・セキュリティ・設計・法令を一括監査
【デプロイ】 /deploy → add → commit → push

【初回リリース】
/infra → /audit → /deploy safe

【育てるサイクル】
実装 → /verify → /deploy → 繰り返し
```

迷ったら `/learn` → 実践 と打てば、プロジェクトの状態を見て次にやることを教えてくれる。

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
| `/design` | 5+パターンでデザイン比較 → 確定 → そのまま実装 |
| `/infra` | 本番インフラの初期セットアップ（Git・GitHub・プラットフォーム・デプロイ設定・ドメイン・DB・監視） |

### 並列実行・調査・監査

| コマンド | 概要 |
|---------|------|
| `/parallel` | タスク分割 → サブエージェントが worktree で並列実装 |
| `/research` | 調査の窓口。テーマ調査 / プロダクト改善調査を選択して実行 |
| `/audit` | 監査（コード・セキュリティ・設計・法令）+ ドキュメント生成を選択して並列実行 |
| `/debate` | 複数のAIエージェントが議論して収束 |

### ユーティリティ

| コマンド | 概要 |
|---------|------|
| `/asset` | アセット調達の窓口。音源 / 画像 / パーティクルを選択して実行 |
| `/backup` | 現在の状態を git コミットで保存（push しない） |
| `/rollback` | 直近コミットから復元先を選択 |

### 学習

| コマンド | 概要 |
|---------|------|
| `/learn` | 開発フロー学習の窓口。入門 / 中級 / 実践を選択して実行 |

## セットアップ

```
~/.claude/
├── agents/           # エージェント定義（11種）
│   ├── code-checker.md      visual-checker.md
│   ├── test-checker.md      log-checker.md
│   ├── audit-code-checker.md   audit-security-checker.md
│   ├── audit-architecture-checker.md  audit-law-checker.md
│   ├── asset-preview-generator.md     release-checker.md
│   └── architecture-generator.md
├── skills/           # スキル定義（16種 + 窓口内references 8種）
│   ├── kickoff/        design/         local/
│   ├── parallel/       verify/         audit/
│   ├── deploy/         backup/         rollback/
│   ├── infra/          debate/         debate-join/
│   ├── skill-check/
│   ├── asset/          ← 窓口（references/: sounds, ai-images, particles）
│   ├── research/       ← 窓口（references/: theme, upgrade）
│   ├── learn/          ← 窓口（references/: frontend-trainer, fullstack-trainer, solo-trainer）
├── docs/             # フロー詳細ドキュメント
├── CLAUDE.md         # 共通ルール
└── settings.json
```

**必要なもの**: Claude Code + Playwright（動的検証で使用）

詳細は [docs/マルチエージェント開発フロー.md](docs/マルチエージェント開発フロー.md) を参照。

## ライセンス

MIT
