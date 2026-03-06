\# 実装タスクのフロー

1\. docs/CORE.md, docs/ARCHITECTURE.md があれば参照
2\. 依存関係確認（変更対象の依存先を検索し影響範囲を把握）
   \- コード依存: 変更対象の参照元・参照先を検索
   \- 概念依存（ビジネスロジック変更時）: 関連キーワードを最低3パターンでgrep → 影響箇所を実装前にユーザーと確認
3\. 設計検討
4\. 実装
5\. 完了報告



\# スクリーンショット管理

\- Playwright スクリーンショットは `check_log/screenshots/` に保存する



\# Git 運用

\- リモート: `origin`（GitHub: ShoYasuda-rex/claude-multi-agent-framework）
\- ブランチ戦略: `master` に直接push（`git push origin master`）
\- 本番ブランチ: `master`



\# エラーの学習

\- 技術的なエラーを修正したら rules\\learned.md に記録する

\- フォーマット: 内容（1行） / 対策（1行）

\- 同じ内容が既にあれば追記しない

