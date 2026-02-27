\# 実装タスクのフロー

1\. docs/CORE.md, docs/ARCHITECTURE.md があれば参照
2\. 依存関係確認（変更対象の依存先を検索し影響範囲を把握）
   \- HTML変更 → JS、CSSセレクタ確認
   \- JS変更 → 呼び出し元、戻り値確認
   \- CSS変更 → 同名class/idの使用箇所確認
3\. 設計検討
4\. 実装
5\. 完了報告



\# スクリーンショット管理

\- Playwright スクリーンショットは必ず `check_log/screenshots/` に保存する（ルートに直接 PNG を置かない）
\- `browser_take_screenshot` の filename には `check_log/screenshots/` プレフィックスを付ける
\- ディレクトリが存在しない場合は事前に `mkdir -p check_log/screenshots` で作成する



\# エラーの学習

\- 技術的なエラーを修正したら rules\\learned.md に記録する

\- フォーマット: 内容（1行） / 対策（1行）

\- 同じ内容が既にあれば追記しない

