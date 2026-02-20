\# ショートカットコマンド

* .tpi → 並列実装。依存関係を調査し、タスク分割した上で方式を自動選択する。メインは調整役のみ（実装はせず、タスク振り分け・結果統合・報告を担当）。

  * 全タスクが独立 → サブエージェント並列（軽量・高速）
  * タスク間に依存関係あり or 動的にタスクが増える → Agent Teams（共有タスクリスト、メンバー間通信、Lead常時インタラクティブ）

* .test → test-runner サブエージェントを呼び出す（テスト実行・結果分析）
* .cc → code-checker サブエージェントを呼び出す（引数なし→直前の実装を検証、引数あり→指定箇所を検証）
* .vc → visual-checker サブエージェントを呼び出す（引数なし→直前の実装を検証、引数あり→指定箇所を検証）
* .spc → audit-spec-checker サブエージェントを呼び出す（仕様適合チェック）
* .cod → audit-code-checker サブエージェントを呼び出す（全体コード監査）
* .sec → audit-security-checker サブエージェントを呼び出す（セキュリティ監査）
* .arc → audit-architecture-checker サブエージェントを呼び出す（アーキテクチャ設計監査）
* .log → log-checker サブエージェントを呼び出す（Herokuログ分析・障害予兆検出）



\# 実装タスクのフロー

1\. Coreの確認: docs/CORE.md を参照（プロダクトの本質・体験方針・トーン）

2\. 仕様の確認: docs/SPEC.md を参照（画面仕様・振る舞い）

3\. アーキテクチャの確認: docs/ARCHITECTURE.md を参照（技術設計・構成）

4\. 依存関係確認: 変更対象ファイルの依存関係を検索し、影響を受けるファイル一覧を把握

5\. 設計検討

6\. 実装

7\. 完了報告



\# 依存関係の確認

\- class名、id、関数名を変更する前に依存先を検索する

\- HTML変更 → 参照しているJS、CSSセレクタを確認

\- JS変更 → 呼び出し元、戻り値の期待を確認

\- CSS変更 → 同名class/idの使用箇所を確認



\# プロジェクトCLAUDE.mdの更新

\- 構造・設計に関わる変更をしたら、プロジェクトのCLAUDE.mdに反映する



\# Bashツール

\- Platform: win32 でも Bashツールは /usr/bin/bash（Git Bash）で動作する
\- 常にbash構文を使う（mkdir -p, rm -f, ls 等）
\- Windows CMD構文は禁止（if not exist, dir, copy 等）
\- Windows固有の操作が必要な場合は bash内から `powershell -Command "..."` で呼ぶ



\# スクリーンショット管理

\- Playwright スクリーンショットは必ず `check_log/screenshots/` に保存する（ルートに直接 PNG を置かない）
\- `browser_take_screenshot` の filename には `check_log/screenshots/` プレフィックスを付ける
\- ディレクトリが存在しない場合は事前に `mkdir -p check_log/screenshots` で作成する



\# エラーの学習

\- 技術的なエラーを修正したら rules\\learned.md に記録する

\- フォーマット: 内容（1行） / 対策（1行）

\- 同じ内容が既にあれば追記しない

