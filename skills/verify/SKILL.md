---
name: verify
description: 実装後の品質チェックを一括実行（テスト・静的検証・動的検証を複数選択して並列実行）
user_invocable: true
---

## 実行フロー

1. ユーザーに実行対象を複数選択で確認する:
   - テスト（test-checker） — テスト生成＋実行（ユニット・インテグレーション・E2E）
   - 静的検証（code-checker） — 依存関係・リント・型チェック・ビルド確認
   - 動的検証（visual-checker） — ブラウザで画面確認

   **デフォルト**: 引数なし → 全て実行（選択UIをスキップ）

2. 選択されたツールを**並列で**サブエージェントとして起動する（Taskツールを使用）:
   - テスト → test-checker エージェント（subagent_type: test-checker）
   - 静的検証 → code-checker エージェント（subagent_type: code-checker）
   - 動的検証 → visual-checker エージェント（subagent_type: visual-checker）

3. 全エージェントの完了を待ち、結果を統合して報告する

## 報告フォーマット

```
## /verify 完了

### テスト（test-checker）
[結果サマリー]

### 静的検証（code-checker）
[結果サマリー]

### 動的検証（visual-checker）
[結果サマリー]

### 総合判定
- CRITICAL: X件
- WARNING: X件
- INFO: X件
```

※選択されなかったツールのセクションは省略する

## ルール

- 最低1つは選択されていること
- 各サブエージェントは独立して並列実行する
- 結果の統合・報告のみメインが行う（検証自体はサブエージェントに任せる）
