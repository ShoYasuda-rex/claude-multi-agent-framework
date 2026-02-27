---
name: verify
description: 実装後の品質チェックを一括実行（テスト・静的検証・動的検証を複数選択して並列実行）
user_invocable: true
---

## 1. 選択

AskUserQuestion（multiSelect: true）で実行する検証を選ばせる:

> どの検証を実行しますか？

| label | description |
|-------|------------|
| 全部実行（Recommended） | テスト + 静的検証 + 動的検証 を一括実行 |
| テスト | テスト生成＋実行（ユニット・インテグレーション・E2E） |
| 静的検証 | 依存関係・リント・型チェック・ビルド確認 |
| 動的検証 | ブラウザで画面確認 |

- 「全部実行」が選ばれた場合 → 3つ全て実行（他の選択は無視）
- それ以外 → 選択されたものだけ実行

---

## 2. コンテキスト収集

サブエージェントに渡すプロジェクト文脈を収集する。

以下のファイルを Read で読む（存在しないものはスキップ）:

1. `docs/CORE.md` — 誰の課題を解決するプロダクトか
2. `docs/ARCHITECTURE.md` — データモデル・API設計・認証方式・外部連携

読み取った内容から、以下の `{project_context}` ブロックを組み立てる:

```
## プロジェクト文脈
- プロダクト概要: （CORE.md の「一言で言うと」）
- 技術スタック: （ARCHITECTURE.md の技術スタックテーブル）
- データモデル: （ARCHITECTURE.md の主要モデル一覧）
- 認証方式: （ARCHITECTURE.md の認証・権限設計）
- 外部連携: （ARCHITECTURE.md の外部API・サービス）
```

CORE.md も ARCHITECTURE.md も存在しない場合、`{project_context}` は空文字にする。

---

## 3. 実行

選択された検証を **Task ツールのサブエージェントとして並列起動** する:

| 検証 | subagent_type |
|------|--------------|
| テスト | test-checker |
| 静的検証 | code-checker |
| 動的検証 | visual-checker |

- 全て `run_in_background: true` で並列実行する
- 選択された Task 呼び出しを **1つのメッセージ内で同時に** 発行すること
- 各サブエージェントの prompt に `{project_context}` を先頭に付与する:

```
{project_context}

上記のプロジェクト文脈を踏まえて検証してください。
```

---

## 4. 結果の集約

全サブエージェントの完了を TaskOutput で待ち、結果を統合して報告する

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
