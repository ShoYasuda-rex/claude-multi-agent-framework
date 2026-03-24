---
name: skill-check
description: スキル設計レビュー（design）またはスキル実行後の挙動検証（run）の窓口
tools: Read, Write, Glob, AskUserQuestion
user-invocable: true
---

# /skill-check

窓口スキル。最初にモードを選び、対応する reference を Read して実行する。

| モード | 用途 | タイミング |
|--------|------|---------|
| **design** | SKILL.md を読み、フロー図・参照・作成ファイルを含む `{スキル名}_DESIGN.md` を生成。スキルの良し悪しを判断する | スキルを作るとき |
| **run** | スキルを実際に動かした後、定義と挙動を突き合わせてレポート | スキルを使った後 |

---

## フロー

### ステップ1: モード選択

AskUserQuestion（multiSelect: false）で聞く:

> どちらを実行しますか？

| label | description |
|-------|-------------|
| design | スキルの {スキル名}_DESIGN.md を生成してフローを確認・評価する |
| run | スキル実行後の定義と挙動を突き合わせる |

### ステップ2: reference を Read して実行

- **design** → `~/.claude/skills/skill-check/references/design.md` を Read し、その手順に従って実行する
- **run** → `~/.claude/skills/skill-check/references/run.md` を Read し、その手順に従って実行する
