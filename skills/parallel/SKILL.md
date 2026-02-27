---
name: parallel
description: 並列実装。タスクを分割し、サブエージェントが同時に実装する
tools: Read, Glob, Grep, Write, Edit, Bash, Task, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TeamCreate, SendMessage
user_invocable: true
model: opus
---

# /parallel

ユーザーの直前の指示をタスクに分割し、複数サブエージェントで並列実装する。

- 全タスクが独立 → Task並列起動（TeamCreate不要）
- タスク間に依存関係あり → TeamCreate で管理

リーダー（メインチャット）は調整のみ。実装はしない。

## フロー

1. 指示をタスクに分割（2〜5個、同一ファイル編集は1エージェントにまとめる）
2. 複数エージェントが別ファイルを同時編集する場合は `isolation: "worktree"` で起動する
3. 1つのメッセージで全エージェントを並列起動
4. 結果を統合してユーザーに報告（worktreeの場合は変更をマージ）

## サブエージェント起動テンプレート

```
Task tool:
  subagent_type: general-purpose
  mode: bypassPermissions
  prompt: |
    以下のタスクを実装してください。
    EnterPlanModeは使うな。AskUserQuestionは使うな。確認せず即実行しろ。
    コード調査が必要ならTaskツール（subagent_type: Explore）に委譲しろ。

    タスク: {task_description}
    対象ファイル: {files}
    コンテキスト: {context}
```
