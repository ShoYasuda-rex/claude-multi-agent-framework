---
name: asset
description: アセット調達の窓口（音源・画像・パーティクル）
model: opus
user_invocable: true
---

# /asset

アセット調達の窓口。種類を選択し、対応するスキルを実行する。

---

## 1. 選択

AskUserQuestion で確認:

> どの種類のアセットを調達しますか？

| label | description |
|-------|------------|
| 音源（BGM・SE） | フリーBGM・SEの調査→自動選定→取得→配置→コード適用→クレジット管理 |
| 画像（AI生成） | ローカルFLUX.1で画像アセットをテイスト確認→一括生成→配置→コード適用→クレジット管理 |
| パーティクルエフェクト | パーティクルエフェクトの設計→プレビュー→エンジン組み込み→コード適用 |

---

## 2. 実行

選択に応じて、対応するスキルの SKILL.md を Read し、その手順に従って最初から実行する:

| 選択 | 読み込むファイル |
|------|----------------|
| 音源 | `skills/get-web-sounds/SKILL.md` |
| 画像 | `skills/gen-ai-pixels/SKILL.md` |
| パーティクル | `skills/gen-particles/skill.md` |
