---
name: gen-pixel
description: ローカルFLUX.1サーバーでドット絵アセットをバッチ生成・配置・クレジット管理
model: opus
user_invocable: true
---

# Gen Pixel

ローカル FLUX.1 OpenVINO サーバー（`http://127.0.0.1:8188`）を使って、ドット絵（ピクセルアート）アセットをバッチ生成するスキル。
ゲーム開発で大量に同スタイルの素材が必要なときに使う。

> **使い分け**:
> `/gen-pixel` — ドット絵をローカルでバッチ生成（キャラ、アイテム、タイル、UI素材）
> `/web-asset` — フリー素材を調達（ライセンス確認付き）
> リアル系・イラスト系の画像 → ブラウザ版AI（ChatGPT, Grok等）を推奨

---

## 0. サーバー起動・接続確認

### 0-1. ヘルスチェック

```bash
curl -s http://127.0.0.1:8188/health
```

- `model_loaded: true` → ステップ 1 へ
- `model_loaded: false` → モデルロード中。ステップ 0-3 へ
- 接続エラー → サーバー未起動。ステップ 0-2 へ

### 0-2. サーバー自動起動

接続エラーの場合、バックグラウンドでサーバーを起動する:

```bash
cd C:/Users/shoya/dev/flux-local-image-gen && ./venv/Scripts/python.exe api_server.py > /dev/null 2>&1 &
```

Bash の `run_in_background: true` で実行する（フォアグラウンドをブロックしない）。

起動後、ステップ 0-3 でモデルロード完了を待つ。

### 0-3. モデルロード待機

モデルロードに約120秒かかる。ユーザーに待機中であることを伝え、20秒間隔でヘルスチェックをポーリング:

```bash
curl -s http://127.0.0.1:8188/health
```

- `model_loaded: true` → ステップ 1 へ
- それ以外 → 20秒後に再チェック（最大10回 = 約200秒）
- 10回超えても `model_loaded: false` → エラー報告して終了

---

## 1. 生成計画

### 1-1. プロジェクト情報の収集（並列実行）

以下を並列で実行:

- CLAUDE.md を Read — 技術スタック・テーマ・用途を把握
- `docs/CORE.md` / `docs/ARCHITECTURE.md` を Read（なければスキップ）
- `public/assets/` と `src/assets/` を Glob — 既存アセットの棚卸し
- `src/` 配下で画像の import/参照を Grep — コードが参照しているアセットパスを特定
- `CREDITS.md` を Read（なければスキップ）

### 1-2. 生成候補の提案

分析結果をもとに、必要なドット絵アセットを提案:

```
## プロジェクト分析結果

- 種別: {ゲームジャンル等}
- テーマ: {雰囲気・トーン}
- 既存アセット: {概要}

## 生成計画

| # | 種類 | サイズ | 枚数 | プロンプト案 | 備考 |
|---|------|--------|------|------------|------|
| 1 | キャラクター | 32x32 | 4枚 | {英語プロンプト案} | 歩行アニメ等 |
| 2 | アイテム | 16x16 | 10枚 | {英語プロンプト案} | 武器・回復等 |
| 3 | タイルセット | 32x32 | 8枚 | {英語プロンプト案} | 地形 |
```

AskUserQuestion で確認（multiSelect: true）:

**質問: どのアセットを生成しますか？**
- 推奨候補を選択肢として提示
- 各選択肢の description にプロンプト案を記載

ユーザーが引数でアセット内容を直接指定した場合は分析をスキップし、ステップ 2 に進む。

---

## 2. プロンプト設計

### ドット絵プロンプトの構成ルール

```
{subject}, pixel art, {pixel size}px style, {color palette}, {background}, {additional style}
```

### ドット絵特化プロンプトテンプレート

**キャラクター:**
```
{character description}, pixel art game sprite, {N}-bit style, {palette} colors, {view direction}, clean pixel edges, no anti-aliasing
```

**アイテム・アイコン:**
```
{item description}, pixel art game icon, 16-bit RPG style, {palette}, black background, game asset, sharp pixels
```

**タイルセット:**
```
{tile description}, pixel art tileset, top-down view, seamless tile, {N}-bit color palette, game asset
```

**背景・風景:**
```
{scene description}, pixel art landscape, {N}-bit style, {mood} atmosphere, {palette} color palette
```

### プロンプト設計ルール

- **英語で記述**（モデルが英語で学習されている）
- **`pixel art` を必ず含める**
- **ドット絵は4ステップ推奨**（8ステップだと描き込みが増えてドット感が薄れる）
- **サイズは小さめ推奨**: 256x256 か 512x512（大きいとドット感が薄れる）
- **`no anti-aliasing`, `sharp pixels`, `clean pixel edges`** でドット感を強調
- **ビット深度を指定**: `8-bit`, `16-bit`, `32-bit` でスタイルを制御
- **カラーパレット制限**: `limited color palette`, `NES palette`, `SNES palette` 等
- **ネガティブプロンプトは不要**（FLUX.1-schnell は対応していない）
- **テキスト描画は不可**（読める文字は生成できない。後加工推奨）

### 人物のドット化が効くプロンプト

単なる `pixel art` は人物に効きにくい。以下を使う:
- `Minecraft character, voxel human, blocky 3D`（ボクセル指定）
- `RPG game sprite sheet, 32x32 pixel character, top-down view`（スプライト指定）
- `chibi pixel character, 16-bit JRPG style`（ちびキャラ指定）

### サイズ選定

| 用途 | 推奨生成サイズ | 最終リサイズ先 |
|------|--------------|--------------|
| スプライト | 256x256 | 32x32, 64x64 |
| アイテムアイコン | 256x256 | 16x16, 32x32 |
| タイル | 256x256 | 32x32, 64x64 |
| 立ち絵・ポートレート | 512x512 | 128x128, 256x256 |
| 背景 | 512x512 | 用途に応じて |

制約: 256〜1024px、大きいほど生成時間が増加（512x512 で約16-19秒）

AskUserQuestion でプロンプトを確認:

**質問: このプロンプトで生成しますか？**（アセットごとに）
- プロンプト案を提示
- 選択肢: 「このまま生成」「プロンプトを修正」「スキップ」

---

## 3. バッチ生成実行

### 3-A. 単一生成（1-2枚）

```bash
curl -s -X POST http://127.0.0.1:8188/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "{prompt}", "width": {W}, "height": {H}, "num_inference_steps": 4, "filename": "{filename}.png"}'
```

### 3-B. バッチ生成（3枚以上）

```bash
curl -s -X POST http://127.0.0.1:8188/batch \
  -H "Content-Type: application/json" \
  -d '{"prompts": [{...}, {...}, {...}]}'
```

バッチの場合はポーリングで完了を待つ:

```bash
curl -s http://127.0.0.1:8188/batch/{job_id}
```

- `status: "running"` → 10秒待って再チェック
- `status: "completed"` → 続行

### 3-C. バリエーション生成

1つのアセットにつき **2-3枚のバリエーション** を生成して選んでもらう戦略:

- 同じプロンプトで複数回生成（シードが毎回変わる）
- または微妙にプロンプトを変えて生成

AskUserQuestion でバリエーション確認:

**質問: バリエーションを生成しますか？**
- 「1枚だけ生成（速い）」
- 「3枚生成して選ぶ（推奨）」

---

## 4. 結果確認と選択

### 4-1. 生成画像のプレビュー

生成された画像を Read ツールで表示（Read は画像をプレビューできる）。

バリエーション生成した場合は全画像を表示し、AskUserQuestion で選択:

**質問: どの画像を使いますか？**
- 候補1（ファイル名を表示）
- 候補2
- 候補3
- 「全部やり直し（プロンプト修正）」

「やり直し」が選ばれた場合 → ステップ 2 に戻る（プロンプト修正 → 再生成）。
最大3回までリトライ。3回で決まらなければ現状の最良を使うか中止するか確認。

### 4-2. 不採用画像の削除

選ばれなかった画像はサーバーの outputs/ から削除:

```bash
rm {不採用画像のパス}
```

---

## 5. 配置

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

## 6. CREDITS.md 更新

プロジェクトルートの `CREDITS.md` を更新（存在しなければ新規作成）。

### AI生成アセットのフォーマット

```markdown
### AI Generated Pixel Art (FLUX.1-schnell)
- **{アセット名}** — AI generated pixel art
  - Model: FLUX.1-schnell (OpenVINO int8)
  - Prompt: `{使用したプロンプト}`
  - Used in: {用途の説明}
```

- 既存エントリと重複しないようファイル名ベースで確認
- AI生成セクションは他のアセット（フリー素材等）とは分離する

---

## 7. 完了報告

```
## Gen Pixel 完了

| # | 種類 | ファイル名 | 生成サイズ | 最終サイズ | 生成時間 | 配置先 |
|---|------|-----------|----------|----------|---------|--------|
| 1 | {種類} | {ファイル名} | {W}x{H} | {W}x{H} | {N}秒 | {パス} |

- プロンプト: `{使用したプロンプト}`
- CREDITS.md: 更新済み
- 合計生成枚数: {N}枚（うち採用: {N}枚）
```

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
