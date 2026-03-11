---
name: learn
description: 開発フロー学習の窓口（入門・中級・実践）
model: opus
user-invocable: true
---

# /learn

開発フロー学習の窓口。レベルを選択し、対応するトレーナースキルを実行する。

---

## 1. 選択

AskUserQuestion で確認:

> どのレベルから始めますか？

| label | description |
|-------|------------|
| 入門（1日） | フロントエンドだけで小さなプロダクトを1つ作り切る。開発フローの型を身体で覚える |
| 中級（2日） | DB + API + Workers を加えたフルスタックプロダクトを1つ作り切る |
| 実践 | 自分でスキルを使って開発を回す練習。トレーナーは横にいて次の1手だけ指示する |

---

## 2. 実行

選択に応じて、対応するスキルの SKILL.md を Read し、その手順に従って最初から実行する:

| 選択 | 読み込むファイル |
|------|----------------|
| 入門 | `~/.claude/skills/learn/references/frontend-trainer.md` |
| 中級 | `~/.claude/skills/learn/references/backend-trainer.md` |
| 実践 | `~/.claude/skills/learn/references/solo-trainer.md` |
