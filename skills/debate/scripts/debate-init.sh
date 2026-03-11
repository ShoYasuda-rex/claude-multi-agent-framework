#!/bin/bash
# debate-init.sh - debateファイル生成 + 4体分プロンプト出力
# Usage: bash debate-init.sh <theme_slug> <theme_jp> [reference_file]
# Output: JSON with file_path + 4 prompts (Claude-A/B/C/V)

SLUG="$1"
THEME="$2"
REF_FILE="$3"

if [ -z "$SLUG" ] || [ -z "$THEME" ]; then
  echo "Usage: bash debate-init.sh <theme_slug> <theme_jp> [reference_file]" >&2
  exit 1
fi

# プロジェクト名
PROJECT=$(basename "$(pwd)")
DIR="$HOME/agent-reports/$PROJECT"
mkdir -p "$DIR"

# ファイル名（Git Bashパス → Windowsパスに変換）
TIMESTAMP=$(date +%Y%m%d_%H%M)
FILEPATH_RAW="$DIR/${TIMESTAMP}_${SLUG}_debate.md"
FILEPATH=$(echo "$FILEPATH_RAW" | sed 's|^/c/|C:/|; s|^/d/|D:/|; s|^/e/|E:/|')

# 参考資料
REF_SECTION=""
if [ -n "$REF_FILE" ] && [ -f "$REF_FILE" ]; then
  REF_CONTENT=$(cat "$REF_FILE")
  REF_SECTION="
## 参考資料

$REF_CONTENT
"
fi

# debateファイル生成（書き込みはraw pathで）
cat > "$FILEPATH_RAW" << DEBATEFILE
# debate

- テーマ: $THEME
- 参加者: Claude-A, Claude-B, Claude-C, Claude-V
- フェーズ: 発散
- 開始: $(date '+%Y-%m-%d %H:%M')
$REF_SECTION
## 発散
DEBATEFILE

# 議論エージェント共通プロンプト（テンプレート）
COMMON_RULES='## ルール
- ファイルが真実。議論の閲覧・書き込みはファイルを直接操作する。
- 日本語で議論。

## 発散フェーズ
- 役割なし。全員フラット。
- 2〜3行の短文のみ。箇条書き・見出し・構造化は禁止。
- 否定OK、賛同OK、脱線OK。深く考えすぎない。即書く。
- 直前の発言者以外が応答。連投防止。
- 発言形式: `### [{自分のID}]` + 2〜3行の短文

## 収束フェーズ（`## 収束` 検知で切り替え）
- `## 収束` 直後の行で役割が割り当てられる（例: Claude-A=設計者, Claude-B=探索者, Claude-C=批評者）
- 順番: 設計者 → 探索者 → 批評者 を1ラウンドとする
- 順番判定: 直前の発言者が批評者 or User → 設計者の番 / 設計者の後 → 探索者 / 探索者の後 → 批評者
- 検証者(Claude-V)の発言は順番に影響しない
- 設計者: 素材を整理・構造化。全指摘に回答（逃げない）。検証者の指摘も反映。
- 探索者: 新しい切り口・見落とし・可能性を投げ込む。設計者を否定しない（批評者の仕事）。
- 批評者: 穴を突く・エッジケース・実現可能性を問う。対案は出さない（設計者の仕事）。
- Round 1: 設計者は発散の素材整理から（自分の案ではなく）。対立意見も両方提示し方針提案。
- Round 2〜: 設計者は探索者案の採否（理由付き）+ 批評者指摘への修正or反論を全て回答。

## 結論（設計者のみ）
- `## 結論へ` を検知したら、設計者がファイル末尾に `## 結論` ドキュメントを書く
- 必須: 概要 / 決定事項 / リスクと対策
- 任意: 採用しなかったアイデア / 技術スタック / UI設計 / データ構造 / フォルダ構成 / KPI / タイムライン等

## 動作ループ
1. ファイルを Read で読む
2. `## 結論` があれば終了
3. `## 収束` がない → 発散モード: 直前の発言者が自分以外なら短文1発言を Edit で追記
4. `## 収束` がある → 収束モード: 自分の役割・順番を確認し、自分の番なら Edit で1発言を追記
5. 設計者のみ: `## 結論へ` 検知 → `## 結論` ドキュメントを書く
6. sleep 3秒 → 1に戻る'

# 検証者プロンプト
V_PROMPT="あなたは debate の **検証者 Claude-V** です。

## debateファイル
\`$FILEPATH\`

## テーマ
$THEME

## あなたの動作

以下のループを繰り返してください:

1. ファイルを Read で読む
2. \`## 結論\` があれば終了
3. \`## 発散\` 以降の新しい発言を確認（\`## 参考資料\` セクションは検証対象外）
4. 事実に基づく主張・数値・技術的前提を検出したら WebSearch で裏取り（1主張につき最大1回の検索。深追いしない）
5. 誤りや不正確な点があれば以下の形式で Edit ツールを使ってファイル末尾に追記:

\`\`\`
### [Claude-V]
⚠️ {誰}の「{主張の要約}」について:
{正しい情報}（出典: {URL or ソース名}）
\`\`\`

6. 議論のテーマや論点に関連する外部事例・ベストプラクティスを WebSearch で見つけたら Edit ツールでファイル末尾に追記して共有:

\`\`\`
### [Claude-V]
📎 {論点やテーマ}に関連する事例:
{事例の概要}（出典: {URL or ソース名}）
\`\`\`

7. 確認できなかった場合・問題なしの場合は何も書かない
8. sleep 5秒 → 1に戻る

## 禁止事項
- 議論に参加しない。意見・対案・設計方針の提案はしない。
- 事実の裏取り・誤りの指摘・外部事例の共有のみ。"

# プロンプトをファイルに書き出してpythonでJSON化
PROMPT_A="あなたは debate の議論参加者 **Claude-A** です。

## debateファイル
\`$FILEPATH\`

## テーマ
$THEME

$COMMON_RULES

即座に議論を開始してください。"

PROMPT_B="あなたは debate の議論参加者 **Claude-B** です。

## debateファイル
\`$FILEPATH\`

## テーマ
$THEME

$COMMON_RULES

即座に議論を開始してください。"

PROMPT_C="あなたは debate の議論参加者 **Claude-C** です。

## debateファイル
\`$FILEPATH\`

## テーマ
$THEME

$COMMON_RULES

即座に議論を開始してください。"

# pythonでJSON生成（エスケープを正確に処理）
export FILEPATH THEME PROMPT_A PROMPT_B PROMPT_C V_PROMPT PYTHONUTF8=1
python -c "
import json, os
data = {
    'file_path': os.environ['FILEPATH'],
    'theme': os.environ['THEME'],
    'prompts': {
        'Claude-A': os.environ['PROMPT_A'],
        'Claude-B': os.environ['PROMPT_B'],
        'Claude-C': os.environ['PROMPT_C'],
        'Claude-V': os.environ['V_PROMPT'],
    }
}
print(json.dumps(data, ensure_ascii=False, indent=2))
" 2>&1

# python失敗時のフォールバック
if [ $? -ne 0 ]; then
  echo "ERROR: python failed. Falling back to plain text output." >&2
  echo "FILE_PATH=$FILEPATH"
  echo "---PROMPT_A---"
  echo "$PROMPT_A"
  echo "---PROMPT_B---"
  echo "$PROMPT_B"
  echo "---PROMPT_C---"
  echo "$PROMPT_C"
  echo "---PROMPT_V---"
  echo "$V_PROMPT"
fi
