---
name: gen-ai-pixels
description: ローカルFLUX.1サーバーで画像アセットをバッチ生成・配置・クレジット管理（ドット絵・アニメ・水彩・リアル等あらゆるスタイル対応）
model: opus
user_invocable: false
---

# Gen AI Pixels

ローカル FLUX.1 OpenVINO サーバー（`http://127.0.0.1:8188`）を使って、画像アセットをバッチ生成するスキル。
ドット絵に限らず、アニメセル画・水彩・油絵・フラットデザイン・サイバーパンク・浮世絵・リアル調など、あらゆるスタイルに対応する。

> **前提条件**: `~/dev/flux-local-image-gen` が必要。存在しない場合はエラーを出して終了する。

---

## 0. サーバー起動 + プロジェクト分析（並列）

サーバー起動とプロジェクト分析を **同時に開始** する。起動待ちの間に分析を終わらせる。

### 0-1. ヘルスチェック → 必要なら起動

```bash
curl -s http://127.0.0.1:8188/health
```

- `model_loaded: true` → サーバー準備完了
- `model_loaded: false` → モデルロード中（ポーリング: 20秒間隔、最大10回）
- 接続エラー → バックグラウンドで起動:

```bash
cd ~/dev/flux-local-image-gen && ./venv/Scripts/python.exe api_server.py > /dev/null 2>&1 &
```

Bash の `run_in_background: true` で実行。10回超えても `model_loaded: false` → エラー報告して終了。

### 0-2. 起動待ちの間にプロジェクト分析（並列実行）

サーバー起動のポーリングと **同時に** 以下を実行:

- CLAUDE.md を Read — 技術スタック・テーマ・用途を把握
- `docs/CORE.md` / `docs/ARCHITECTURE.md` を Read（なければスキップ）
- `public/assets/` と `src/assets/` を Glob — 既存アセットの棚卸し
- `src/` 配下で画像の import/参照を Grep — コードが参照しているアセットパスを特定
- `CREDITS.md` を Read（なければスキップ）

---

## 1. プロンプト設計

テンプレートは使わない。**必ず `docs/MODEL_CHARACTERISTICS.md` を Read してから**プロンプトを設計する。特にセクション9（プロンプト設計の知見）を参照。

### 基本原則

- **英語で記述**
- **背景は `solid black background` を入れる**（remove_bgで透過するため）
- ネガティブプロンプトは不要（FLUX.1-schnell は非対応）
- テキスト描画は不可（後加工推奨）

### サイズ・ステップ

- **512×512 / 4ステップが推奨**（コスパ最良）
- ドット絵を狙う場合は256×256も有効（ドット感が強まる）
- 8ステップはリアル系には有効だが、ドット絵には逆効果
- 制約: 256〜1024px

### サイズ選定（リサイズ用）

| 用途 | 推奨生成サイズ | 最終リサイズ先 |
|------|--------------|--------------|
| スプライト | 256x256 | 32x32, 64x64 |
| アイテムアイコン | 256x256 | 16x16, 32x32 |
| タイル | 256x256 | 32x32, 64x64 |
| 立ち絵・ポートレート | 512x512 | 128x128, 256x256 |
| 背景 | 512x512 | 用途に応じて |

プロンプトは自動設計してそのまま生成に進む（確認不要）。

---

## 2. テイスト確認

### 2-0. 既存アセットとのテイスト方針確認

ステップ 0 の分析で既存アセットが見つかった場合、**生成前に** アセットフォルダをエクスプローラーで開いてユーザーに確認する:

```bash
start "" "{既存アセットのディレクトリパス}"
```

AskUserQuestion で確認:

**質問: 既存アセットと同じテイストで統一しますか？**
- **統一する** → 既存アセットのテイストをベースプロンプトとして確定。5パターン生成をスキップし、ステップ 3（残りを一括生成）へ直行
- **変える** → 下記の5パターン生成に進む

既存アセットがない場合は、この確認をスキップして5パターン生成に進む。

### 2-1. テイスト候補を5パターン生成

生成計画の **最初の1枚の題材** で **5パターン** を生成する。
- **2枠: kawaii-but-intimidating chibi**（確定スタイルのバリエーション違い。表情・ポーズ・ディテールを変える）
- **3枠: 他スタイル**（ユーザー好みから選択。水彩・アニメ・pixel等）

**確定済みスタイル（Task Chronicle プロジェクト）:**

プロンプトテンプレート（キャラ・敵・ボス共通）:
```
chibi [name], super deformed adorable [description], big sparkly [emotion] eyes, oversized [weapon/feature], tiny body in [outfit], [hair description], [cute pose/action], kawaii but [heroic/intimidating/crafty etc], solid black background
```

テイスト固定ワード（これらを必ずプロンプトに含めること）:
- `sparkly` or `sparkling` — 目の描写に必須。`intense`, `focused` 単体だとリアル寄りに崩れる
- `adorable` — 冒頭の描写に入れると全体がchibi寄りに安定する
- `tiny body` — `muscular`, `massive` 等の体型形容詞を避ける（リアル化トリガー）
- `cute [action]` — ポーズ/アクションに `cute` を付けると柔らかくなる
- 髪の描写を必ず入れる — 省略するとモデルが勝手にリアル寄りの解釈をする

NGワード（テイスト崩壊トリガー）:
- `muscular`, `massive`, `towering` — 体型がリアル化する
- `intense`, `fierce` 単体 — 目がリアル寄りになる（`sparkly determined` のように sparkly と組み合わせればOK）
- `realistic`, `detailed` — chibi感が消える
- 髪の描写なし — スキンヘッド等の特殊解釈に収束しやすい

既存アセットの特徴:
- 大きなキラキラ目（sparkly / determined / menacing + sparkly の組み合わせ）
- 丸っこい体型（round, chubby, tiny body — muscular禁止）
- 明るい色調（bright, vibrant colors）
- 可愛さと強さの両立（kawaii but intimidating / heroic / villainous）
- super deformed（2-3頭身）
- 髪の描写を必ず含む

**ユーザーの好み（200枚レビュー + 実制作で確定）:**

全体傾向: **明るく可愛い・クリーンで視認性の高い画像**を好む。暗く重厚な画風は合わない。

スタイル別:
- ◎ 確定: **kawaii-but-intimidating chibi**（全キャラ・敵・ボスで採用済み）、アイコン調（アイテム・UI素材）
- ○ 好む: アニメセル画、水彩（特にペット・自然系）、pixel（背景・雑魚敵向き）
- △ 場合による: ジブリ風、ペーパークラフト、フラット（neutralに偏る）
- × 避ける: **ダークファンタジー**（bad率65%）、浮世絵、ステンドグラス、UE5リアル、レトロ80s、サイバーパンク

被写体×スタイルの最適組み合わせ:
| 被写体 | ベストスタイル | 避けるべき |
|--------|-------------|-----------|
| プレイヤーキャラ | kawaii chibi (heroic) | darkfantasy |
| ボス | kawaii chibi (intimidating) | darkfantasy |
| 雑魚敵 | kawaii chibi (villainous) | darkfantasy |
| 背景 | pixel, watercolor | anime |
| アイテム・UI | スタイルなし（アイコン調） | — |
| NPC | kawaii chibi | darkfantasy |
| ペット | chibi, watercolor | — |
| 環境オブジェクト | スタイルなし | 暗い・不気味な題材 |

**ファイル名は `{連番}_{スタイル名}` にする**（例: `1_watercolor`, `2_chibi`, `3_anime`）。
APIサーバーが自動で4文字ハッシュを付加するため（`1_watercolor_a3f2.png`）、何度生成してもファイル名は衝突しない。

```bash
curl -s -X POST http://127.0.0.1:8188/batch \
  -H "Content-Type: application/json" \
  -d '{"prompts": [{"prompt": "...", "filename": "1_watercolor"}, {"prompt": "...", "filename": "2_chibi"}, ...]}'
```

### 3-2. プレビューと選択

生成完了後、出力フォルダをエクスプローラーで開く:

```bash
start "" "{output_dir}"
```

5枚すべてを Read ツールで表示し、AskUserQuestion で選択。**選択肢にはファイル名と同じスタイル名を表示**する:

**質問: どのテイストで進めますか？**
- 1_watercolor（水彩画風）
- 2_chibi（ちびキャラ）
- 3_anime（アニメセル画）
- 4_flat（フラットデザイン）
- 5_ukiyoe（浮世絵風）
- 「全部やり直し」

「やり直し」の場合 → プロンプトを調整して再生成（最大3回）。
3回で決まらなければ現状の最良を使うか中止するか確認。

選ばれたパターンのプロンプトを **ベースプロンプト** として確定し、残りの生成に使う。

---

## 3. 残りを一括生成

テイスト確定後、残りのアセットをまとめて生成する。

### 4-A. バッチ生成

全プロンプトに **`"remove_bg": true` を常に付与**する（ゲームアセットは透過が基本）。

```bash
curl -s -X POST http://127.0.0.1:8188/batch \
  -H "Content-Type: application/json" \
  -d '{"prompts": [{"prompt": "...", "filename": "...", "remove_bg": true}, ...]}'
```

ポーリングで完了を待つ:

```bash
curl -s http://127.0.0.1:8188/batch/{job_id}
```

- `status: "running"` → 10秒待って再チェック
- `status: "completed"` → 続行

### 4-B. 結果プレビュー

生成完了後、出力フォルダをエクスプローラーで開く:

```bash
start "" "{output_dir}"
```

全生成画像を Read ツールで表示。
明らかに失敗した画像（崩れ・意図と大きく異なる）があれば、その分だけ再生成する。

### 4-C. 不採用画像の削除

不要な画像はサーバーの outputs/ から削除:

```bash
rm {不採用画像のパス}
```

---

## 4. 配置

### 5-1. 配置先パスの決定

1. 既存アセットのディレクトリ構造を参照
2. **既存構造があればそれに従う**
3. **なければ `public/assets/sprites/` に配置**
4. ディレクトリが存在しなければ `mkdir -p` で作成

### 5-2. コピーとリネーム

サーバーの outputs/ から配置先にコピー:

```bash
cp {outputs/内のパス} {配置先パス}/{リネーム後ファイル名}.png
```

リネーム規則:
- スネークケース
- 用途がわかる名前（例: `sword_iron.png`, `slime_green.png`, `tile_grass.png`）
- 日付やハッシュは含めない

### 5-3. リサイズ（必要な場合）

生成サイズ（256x256等）から最終サイズ（32x32等）にリサイズ:

```bash
magick convert {input} -resize {W}x{H} -filter point {output}
```

**`-filter point` が重要** — ドット絵のリサイズはニアレストネイバー法を使う（バイリニアだとぼやける）。

拡大する場合も同様:
```bash
magick convert {input} -resize {W}x{H} -filter point {output}
```

ImageMagick 未インストール時は手動変換を案内。

### 5-4. 確認

```bash
ls -la {配置先パス}
```

配置した画像を Read ツールでプレビュー表示。

---

## 5. コード適用

配置した画像を実際にコードに組み込む。

### 6-1. 適用先の特定

ステップ 1 の分析結果を活用:

- **コードが参照しているが存在しなかった画像ファイル** → パスを合わせて配置済みなら適用不要
- **新規追加のアセット** → 使用箇所を特定または新規作成

Grep で既存の画像参照パターンを検索:
- `import.*\.(png|gif|webp)`, `src=`, `url(`, `background`, `Image(`, `new Image`
- ゲームフレームワーク固有: `loadImage`, `Sprite`, `Texture`, `tilemap`

### 6-2. 適用パターン

プロジェクトの技術スタックに合わせて適用:

**バニラJS / Canvas:**
```js
const img = new Image();
img.src = 'assets/sprites/slime_green.png';
```

**CSS背景:**
```css
.enemy { background-image: url('assets/sprites/slime_green.png'); }
```

**既存のアセット管理がある場合:**
- 既存パターンに従って追加（アセットローダー、定数ファイル、スプライトマップ等）

### 6-3. 適用ルール

- **既存の画像読み込みパターンがあれば必ずそれに従う**（独自実装しない）
- **画像ファイルパスは配置先と一致させる**（相対パス / 絶対パスはプロジェクトの慣習に合わせる）
- **ドット絵の場合**: CSS `image-rendering: pixelated;` を適用してぼやけ防止（既存設定があればそちらに従う）

---

## 6. CREDITS.md 更新

プロジェクトルートの `CREDITS.md` を更新（存在しなければ新規作成）。

### AI生成アセットのフォーマット

```markdown
### AI Generated Images (FLUX.1-schnell)
- **{アセット名}** — AI generated image
  - Model: FLUX.1-schnell (OpenVINO int8)
  - Prompt: `{使用したプロンプト}`
  - Used in: {用途の説明}
```

- 既存エントリと重複しないようファイル名ベースで確認
- AI生成セクションは他のアセット（フリー素材等）とは分離する

---

## 7. 完了報告

```
## Gen AI Pixels 完了

| # | 種類 | ファイル名 | 生成サイズ | 最終サイズ | 生成時間 | 配置先 |
|---|------|-----------|----------|----------|---------|--------|
| 1 | {種類} | {ファイル名} | {W}x{H} | {W}x{H} | {N}秒 | {パス} |

- プロンプト: `{使用したプロンプト}`
- CREDITS.md: 更新済み
- 合計生成枚数: {N}枚（うち採用: {N}枚）
```

---

## 8. アセットプレビュー更新

Task（subagent_type: asset-preview）を起動し、`public/assets/preview.html` を再生成する。

---

## 制約事項

- **サーバーが起動していないと使えない** — 接続確認で案内
- **1枚あたり約16-19秒**（512x512, 4ステップ） — 大量生成は時間がかかる
- **テキスト描画は苦手** — 文字入りアセットは別ツールを推奨
- **サイズ制約: 256〜1024px** — それ以上は生成不可
- **FLUX.1-schnell はネガティブプロンプト非対応**
- **リサイズ時は必ず `-filter point`**（ニアレストネイバー）を使う
- **生成画像の著作権**: AI生成物の著作権は国・地域で解釈が異なる。商用利用する場合はユーザーの判断に委ねる

## 禁止事項

- 実在の人物・キャラクターを模倣するプロンプトの生成
- 商標・ロゴの模倣
- 不適切なコンテンツの生成
