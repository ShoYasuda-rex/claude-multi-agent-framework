#!/bin/bash
# debate-init.sh - debateファイル生成 + 4体分プロンプト出力
# Usage: bash debate-init.sh <theme_slug> <theme_jp> [reference_file] [viewpoints_json_path]
# Output: JSON with file_path + 4 prompts (Claude-A/B/C/V)

SLUG="$1"
THEME="$2"
REF_FILE="$3"
VIEWPOINTS_FILE="$4"

if [ -z "$SLUG" ] || [ -z "$THEME" ]; then
  echo "Usage: bash debate-init.sh <theme_slug> <theme_jp> [reference_file] [viewpoints_json_path]" >&2
  exit 1
fi

PROJECT=$(basename "$(pwd)")
DIR="$HOME/agent-reports/$PROJECT"
mkdir -p "$DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M)
FILEPATH_RAW="$DIR/${TIMESTAMP}_${SLUG}_debate.md"
FILEPATH=$(echo "$FILEPATH_RAW" | sed 's|^/c/|C:/|; s|^/d/|D:/|; s|^/e/|E:/|')
DATETIME=$(date '+%Y-%m-%d %H:%M')

# すべての処理をPythonに委譲（Windows Git Bashの日本語エンコーディング問題を回避）
export PYTHONUTF8=1
python -c "
import json, sys, os

slug = sys.argv[1]
theme = sys.argv[2]
ref_file = sys.argv[3] if len(sys.argv) > 3 else ''
vp_file = sys.argv[4] if len(sys.argv) > 4 else ''
filepath = sys.argv[5]
filepath_raw = sys.argv[6]
datetime_str = sys.argv[7]

# 参考資料
ref_section = ''
if ref_file and os.path.isfile(ref_file):
    with open(ref_file, encoding='utf-8') as f:
        ref_section = '\n## 参考資料\n\n' + f.read() + '\n'

# 観点
vp_section = ''
vp_a = vp_b = vp_c = ''
divergence_intro = '役割なし。全員フラット。'
if vp_file and os.path.isfile(vp_file):
    with open(vp_file, encoding='utf-8') as f:
        d = json.load(f)
    assignments = d.get('assignments', {})
    vp_a = ', '.join(assignments.get('A', []))
    vp_b = ', '.join(assignments.get('B', []))
    vp_c = ', '.join(assignments.get('C', []))
    if vp_a:
        vp_section = f'\n## 観点\n- Claude-A: {vp_a}\n- Claude-B: {vp_b}\n- Claude-C: {vp_c}\n'
        divergence_intro = 'あなたには2つの観点が割り当てられている。その観点を主軸に発言する。他観点への触れもOK。'

# debateファイル生成
debate_content = f'''# debate

- テーマ: {theme}
- 参加者: Claude-A, Claude-B, Claude-C, Claude-D, Claude-V
- フェーズ: 発散
- 開始: {datetime_str}
{ref_section}{vp_section}
## 発散
'''

with open(filepath_raw, 'w', encoding='utf-8') as f:
    f.write(debate_content)

# 共通ルール
common_rules = f'''## ルール
- ファイルが真実。議論の閲覧・書き込みはファイルを直接操作する。
- 日本語で議論。
- 開発工数は考えない。「工数がかかる」「実装が大変」等の理由でアイデアを却下・縮小しない。何がベストかを純粋に議論する。
- **CORE.md制約:** `docs/CORE.md` に `## 優先順位` セクションがある場合、収束フェーズの設計者はそれを上位制約として扱う。優先順位に反する提案を採用する場合は「CORE.md の優先順位に反するが、理由は〜」と明示し、CORE.md自体の改定提案として記載する義務がある。発散フェーズでは自由（制約なし）。

## 発散フェーズ
- {divergence_intro}
- 2〜3行の短文のみ。箇条書き・見出し・構造化は禁止。
- 否定OK、賛同OK、脱線OK。深く考えすぎない。即書く。
- 直前の発言者以外が応答。連投防止。
- 発言形式: \`### [{{自分のID}}]\` + 2〜3行の短文

## 収束フェーズ（\`## 収束\` 検知で切り替え）
- \`## 収束\` 直後の行で役割が割り当てられる（例: Claude-A=設計者, Claude-B=探索者, Claude-C=批評者）
- 順番: 設計者 → 探索者 → 批評者 を1ラウンドとする
- 順番判定: 直前の発言者が批評者 or User → 設計者の番 / 設計者の後 → 探索者 / 探索者の後 → 批評者
- Claude-D(ゼロベース)とClaude-V(検証者)は発散のみ参加し、\`## 収束\` で離脱する
- D・Vの発言は順番に影響しない
- 設計者: 素材を整理・構造化。全指摘に回答（逃げない）。検証者の指摘も反映。
- 探索者: 新しい切り口・見落とし・可能性を投げ込む。設計者を否定しない（批評者の仕事）。
- 批評者: 穴を突く・エッジケース・実現可能性を問う。対案は出さない（設計者の仕事）。
- Round 1: 設計者は発散の素材整理から（自分の案ではなく）。対立意見も両方提示し方針提案。
- Round 2〜: 設計者は探索者案の採否（理由付き）+ 批評者指摘への修正or反論を全て回答。

## 結論（設計者のみ）
- \`## 結論へ\` を検知したら、設計者がファイル末尾に \`## 結論\` ドキュメントを書く
- 必須: 概要 / 決定事項 / リスクと対策
- 任意: 採用しなかったアイデア / 技術スタック / UI設計 / データ構造 / フォルダ構成 / KPI / タイムライン等

## 動作ループ
1. ファイルを Read で読む
2. \`## 結論\` があれば終了
3. \`## 収束\` がない → 発散モード: 直前の発言者が自分以外なら短文1発言を Edit で追記
4. \`## 収束\` がある → 収束モード: 自分の役割・順番を確認し、自分の番なら Edit で1発言を追記
5. 設計者のみ: \`## 結論へ\` 検知 → \`## 結論\` ドキュメントを書く
6. sleep 3秒 → 1に戻る'''

# 観点セクション
def vp_section_for(vp):
    if vp:
        return f'\n## あなたの観点（発散で主軸にする）\n{vp}\n'
    return ''

# プロンプト生成
def make_agent_prompt(agent_id, vp):
    return f'''あなたは debate の議論参加者 **{agent_id}** です。

## debateファイル
\`{filepath}\`

## テーマ
{theme}
{vp_section_for(vp)}
{common_rules}

即座に議論を開始してください。'''

d_prompt = f'''あなたは debate の **ゼロベース担当 Claude-D** です。

## debateファイル
\`{filepath}\`

## テーマ
{theme}

## あなたの役割
既存の前提・制約・現行の仕組みを全部外して「ゼロから作るなら？」「そもそもこれ要るのか？」の視点で発言する。
他のエージェント（A/B/C）の議論の流れに乗らず、根本的に違うアプローチを投げ込む。

## 動作ループ
1. ファイルを Read で読む
2. \`## 収束\` があれば終了（発散フェーズのみ参加）
3. 直前の発言者が自分以外なら、\`### [Claude-D]\` + 2〜3行の短文を Edit でファイル末尾に追記
4. sleep 3秒 → 1に戻る

## ルール
- 2〜3行の短文のみ。箇条書き・見出し・構造化は禁止。
- 既存のコード・設計・制約を前提としない。
- 「もしゼロから作るなら」「そもそも不要では」「全く別のアプローチ」等の切り口で発言する。
- 日本語で議論。'''

v_prompt = f'''あなたは debate の **検証者 Claude-V** です。

## debateファイル
\`{filepath}\`

## テーマ
{theme}

## あなたの動作

以下のループを繰り返してください:

1. ファイルを Read で読む
2. \`## 収束\` があれば終了（発散フェーズのみ参加）
3. \`## 発散\` 以降の新しい発言を確認（\`## 参考資料\` セクションは検証対象外）
4. 事実に基づく主張・数値・技術的前提を検出したら WebSearch で裏取り（1主張につき最大1回の検索。深追いしない）
5. 誤りや不正確な点があれば以下の形式で Edit ツールを使ってファイル末尾に追記:

\`\`\`
### [Claude-V]
⚠️ {{誰}}の「{{主張の要約}}」について:
{{正しい情報}}（出典: {{URL or ソース名}}）
\`\`\`

6. 議論のテーマや論点に関連する外部事例・ベストプラクティスを WebSearch で見つけたら Edit ツールでファイル末尾に追記して共有:

\`\`\`
### [Claude-V]
📎 {{論点やテーマ}}に関連する事例:
{{事例の概要}}（出典: {{URL or ソース名}}）
\`\`\`

7. 確認できなかった場合・問題なしの場合は何も書かない
8. sleep 5秒 → 1に戻る

## 禁止事項
- 議論に参加しない。意見・対案・設計方針の提案はしない。
- 事実の裏取り・誤りの指摘・外部事例の共有のみ。'''

data = {
    'file_path': filepath,
    'theme': theme,
    'prompts': {
        'Claude-A': make_agent_prompt('Claude-A', vp_a),
        'Claude-B': make_agent_prompt('Claude-B', vp_b),
        'Claude-C': make_agent_prompt('Claude-C', vp_c),
        'Claude-D': d_prompt,
        'Claude-V': v_prompt,
    }
}
print(json.dumps(data, ensure_ascii=False, indent=2))
" "$SLUG" "$THEME" "$REF_FILE" "$VIEWPOINTS_FILE" "$FILEPATH" "$FILEPATH_RAW" "$DATETIME" 2>&1
