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

## 原則: 全操作worktree分離

**全てのサブエージェントは `isolation: "worktree"` で起動する。例外なし。**

- タスクが1個でもworktreeで実行する
- mainは常にクリーンな状態を保つ（誰も直接触らない）
- 完了したものから順にmainへマージ
- 衝突はマージ時にgitが検知 → 手動解決

## フロー

1. 指示をタスクに分割（1〜5個、同一ファイル編集は1エージェントにまとめる）
2. 全エージェントを `isolation: "worktree"` で起動（1つのメッセージで並列起動）
3. 完了したworktreeから順にmainへマージ
4. 衝突があれば解決し、結果を統合してユーザーに報告

## サブエージェント起動テンプレート

```
Task tool:
  subagent_type: general-purpose
  mode: bypassPermissions
  isolation: "worktree"
  prompt: |
    以下のタスクを実装してください。
    EnterPlanModeは使うな。AskUserQuestionは使うな。確認せず即実行しろ。
    コード調査が必要ならTaskツール（subagent_type: Explore）に委譲しろ。

    タスク: {task_description}
    対象ファイル: {files}
    コンテキスト: {context}
```
