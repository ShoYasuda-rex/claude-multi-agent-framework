---
name: make-asset
description: ローカルFLUX.1サーバーでAI画像アセットを生成・配置・クレジット管理
model: opus
user_invocable: true
---

# Make Asset

ローカル FLUX.1 OpenVINO サーバー（`http://127.0.0.1:8188`）を使って、プロジェクト用の画像アセットをAI生成するスキル。
フリー素材では見つからない・プロジェクト固有のビジュアルが必要なときに使う。

> **get-asset との使い分け**:
> `/get-asset` — フリー素材を調達（ライセンス確認付き）
> `/gen-asset` — AI で画像を生成（プロジェクト固有のビジュアル）

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

## 1. プロジェクト分析と生成計画

### 1-1. プロジェクト情報の収集（並列実行）

以下を並列で実行:

- CLAUDE.md を Read — 技術スタック・テーマ・用途を把握
- `docs/CORE.md` / `docs/ARCHITECTURE.md` を Read（なければスキップ）
- `public/assets/` と `src/assets/` を Glob — 既存アセットの棚卸し
- `src/` 配下で画像の import/参照を Grep — コードが参照しているアセットパスを特定
- `CREDITS.md` を Read（なければスキップ）

### 1-2. 生成候補の提案

分析結果をもとに、AI生成が有効なアセットを提案:

```
## プロジェクト分析結果

- 種別: {Webアプリ / ゲーム / LP 等}
- テーマ: {雰囲気・トーン}
- 既存アセット: {概要}

## AI生成の推奨アセット

| # | 用途 | 推奨サイズ | プロンプト案 | 理由 |
|---|------|-----------|------------|------|
| 1 | {用途} | {W}x{H} | {英語プロンプト案} | {なぜAI生成が適切か} |
| 2 | {用途} | {W}x{H} | {英語プロンプト案} | {なぜAI生成が適切か} |
```

AskUserQuestion で確認（multiSelect: true）:

**質問: どのアセットを生成しますか？**
- 推奨候補を選択肢として提示
- 各選択肢の description にプロンプト案を記載

ユーザーが引数でアセット内容を直接指定した場合は分析をスキップし、ステップ 2 に進む。

---

## 2. プロンプト設計

選択されたアセットごとにプロンプトを設計する。

### プロンプト構成ルール

サーバー側で自動付与される prefix: `Japanese illustration style, `

ユーザーに送信するプロンプト（英語）の構成:

```
{subject}, {style descriptors}, {color/mood}, {background}, {technical quality}
```

例:
- `a cute fox mascot character, flat design, orange and white, transparent background, clean lines, vector art style`
- `pixel art treasure chest, 16-bit style, golden with gems, dark background, game asset`
- `fantasy landscape with mountains and castle, soft watercolor, pastel colors, wide shot`

### ポイント

- **英語で記述**（モデルが英語で学習されている）
- **具体的に**（曖昧な指示は品質が下がる）
- **既存アセットのスタイルに合わせる**（ステップ1の分析結果を反映）
- **背景指定を忘れない**（UIアセットなら `transparent background` や `solid color background`）
- **ネガティブプロンプトは不要**（FLUX.1-schnell は対応していない）

### サイズ選定

| 用途 | 推奨サイズ |
|------|-----------|
| アイコン・アバター | 512x512 |
| バナー・ヘッダー | 1024x512 |
| 背景画像 | 1024x1024 |
| カード・サムネイル | 512x768 |
| UIパーツ | 256x256 |

制約: 256〜1024px、大きいほど生成時間が増加（512x512 で約16-19秒）

AskUserQuestion でプロンプトを確認:

**質問: このプロンプトで生成しますか？**（アセットごとに）
- プロンプト案を提示
- 選択肢: 「このまま生成」「プロンプトを修正」「スキップ」

---

## 3. 生成実行

### 3-A. 単一生成（1-2枚）

```bash
curl -s -X POST http://127.0.0.1:8188/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "{prompt}", "width": {W}, "height": {H}, "num_inference_steps": 4, "filename": "{filename}.png"}'
```

### 3-B. バッチ生成（3枚以上、または同一アセットのバリエーション）

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
3. **なければ `public/assets/generated/` に配置**
4. ディレクトリが存在しなければ `mkdir -p` で作成

### 5-2. コピーとリネーム

サーバーの outputs/ から配置先にコピー:

```bash
cp {outputs/内のパス} {配置先パス}/{リネーム後ファイル名}.png
```

リネーム規則:
- スネークケース
- 用途がわかる名前（例: `hero_banner.png`, `fox_mascot.png`）
- 日付やハッシュは含めない

### 5-3. 加工（必要な場合のみ）

- **リサイズ**: `magick convert {input} -resize {W}x{H} {output}`
- **背景除去が必要な場合**: 手動対応を案内（AI生成で透過背景は不完全なため）
- **形式変換**: `magick convert {input} {output.webp}` 等
- ImageMagick 未インストール時は手動変換を案内

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
### AI Generated (FLUX.1-schnell)
- **{アセット名}** — AI generated
  - Model: FLUX.1-schnell (OpenVINO int8)
  - Prompt: `{使用したプロンプト}`
  - Used in: {用途の説明}
```

- 既存エントリと重複しないようファイル名ベースで確認
- AI生成セクションは他のアセット（フリー素材等）とは分離する

---

## 7. 完了報告

```
## Gen Asset 完了

| # | 用途 | ファイル名 | サイズ | 生成時間 | 配置先 |
|---|------|-----------|--------|---------|--------|
| 1 | {用途} | {ファイル名} | {W}x{H} | {N}秒 | {パス} |

- プロンプト: `{使用したプロンプト}`
- CREDITS.md: 更新済み
```

---

## 制約事項

- **サーバーが起動していないと使えない** — 接続確認で案内
- **1枚あたり約16-19秒**（512x512, 4ステップ） — 大量生成は時間がかかる
- **透過背景は不完全** — UIアイコン等で透過が必要な場合は後処理が必要
- **テキスト描画は苦手** — 文字入りアセットは別ツールを推奨
- **サイズ制約: 256〜1024px** — それ以上は生成不可
- **FLUX.1-schnell はネガティブプロンプト非対応**
- **生成画像の著作権**: AI生成物の著作権は国・地域で解釈が異なる。商用利用する場合はユーザーの判断に委ねる

## 禁止事項

- 実在の人物・キャラクターを模倣するプロンプトの生成
- 商標・ロゴの模倣
- 不適切なコンテンツの生成
