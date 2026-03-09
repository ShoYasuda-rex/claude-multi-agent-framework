---
name: research
description: 調査の窓口（テーマ調査・プロダクト改善調査）
model: opus
user_invocable: true
---

# /research

調査の窓口。目的を選択し、対応するスキルを実行する。

---

## 1. 選択

AskUserQuestion で確認:

> どんな調査をしますか？

| label | description |
|-------|------------|
| テーマを調査 | 任意のテーマを多角的に並列調査し、レポートを `.reports/` に出力 |
| プロダクトを改善 | 5視点（UX・ユーザー・競合・再構想・ビジュアル）で並列調査し、改善レポートを `.reports/` に出力 |

---

## 2. 実行

選択に応じて、対応するスキルの SKILL.md を Read し、その手順に従って最初から実行する:

| 選択 | 読み込むファイル |
|------|----------------|
| テーマを調査 | `skills/research-team/SKILL.md` |
| プロダクトを改善 | `skills/upgrade-team/SKILL.md` |
