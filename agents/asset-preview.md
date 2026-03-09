---
name: asset-preview
description: プロジェクトのアセット（画像・音声）をスキャンしてプレビューHTML生成
model: sonnet
---

# Asset Preview

プロジェクトのアセット（画像・音声）をスキャンし、ブラウザで一覧プレビューできるHTMLファイルを生成する。

---

## 手順

### 1. プロジェクト分析

- CLAUDE.md を Read して技術スタックとフォントを把握
- `public/` と `src/assets/` を Glob でスキャンし、全アセットファイルを収集:
  - 画像: `*.png`, `*.jpg`, `*.gif`, `*.webp`, `*.svg`
  - 音声: `*.mp3`, `*.wav`, `*.ogg`, `*.m4a`
- `src/` 配下で画像/音声の import・参照を Grep し、各アセットの用途を特定
- CREDITS.md があれば Read して出典情報を取得

### 2. カテゴリ分類

収集したアセットを以下のルールで自動分類する:

- **ディレクトリ名ベース**: `sprites/enemies/` → "敵キャラ"、`sounds/bgm/` → "BGM" など
- **ファイル名パターン**: `player_*` → "プレイヤー"、`icon_*` → "アイコン" など
- **コード参照**: enemies.ts の `stage: 1` → "ステージ1" のようにコードの文脈からグルーピング
- **表示言語**: カテゴリ名・表示名はすべて日本語にする

分類の粒度はアセット数に応じて調整:
- 10個以下: フラットに全表示
- 11〜30個: 種類別（sprites / sounds / ui）
- 31個以上: 種類＋サブカテゴリ（sprites/enemies/stage1 等）

### 3. HTML生成

`public/assets/preview.html` を Write で生成（既に存在する場合は上書き）。

#### 必須要件

- **スタンドアロンHTML**: 外部JSフレームワーク不要、CDNフォントのみ許可
- **フォント**: プロジェクトの CLAUDE.md に記載のフォントを使用（なければ monospace）
- **ダークテーマ**: 背景 `#0f1923`、ゲームアセットが映える配色
- **レスポンシブ**: CSS Grid の `auto-fill` で画面幅に自動対応
- **パス情報つき**: 各アセットにファイルパスを表示（コードで参照する際にコピーしやすい）
- **戻るリンク**: `< アプリに戻る` で `/` に遷移

#### 画像アセットの表示

```html
<div class="card">
  <img src="{アセットのパス}" alt="{名前}">
  <span class="name">{表示名}</span>
  <span class="meta">{カテゴリ・ステージ等}</span>
  <span class="path">{相対パス}</span>
</div>
```

- グリッドレイアウト（カード形式）
- 画像サイズ: 96x96px（スプライト）、アスペクト比に応じて調整
- ホバーでボーダー色変更
- `drop-shadow` でゲーム風のグロー効果

#### 音声アセットの表示

```html
<div class="sound-row">
  <span class="name">{表示名}</span>
  <audio controls preload="none" src="{パス}"></audio>
  <span class="meta">{相対パス}</span>
</div>
```

- ネイティブ `<audio>` コントロールで再生可能
- `preload="none"` でページロード時の通信を抑える

#### CREDITS情報

CREDITS.md の内容がある場合、各アセットカードに出典元を表示:

```html
<span class="credit">by {作者名}</span>
```

### 4. 表示確認

- 生成したHTMLを Playwright の `browser_navigate` で開く
- `browser_take_screenshot` でフルページスクリーンショットを撮影
- `check_log/screenshots/asset_preview.png` に保存

### 5. 完了報告

```
Asset Preview 生成完了
- URL: /assets/preview.html
- 画像: {N}枚
- 音声: {N}件
- カテゴリ: {カテゴリ一覧}
```

---

## 注意事項

- `public/` 配下の静的ファイルのみ対象（`src/assets/` の import 系は参照情報として使うが、プレビューパスは `/assets/...` に変換）
- PWA アイコン（`pwa-*.png`）やファビコンはスキップする
- Vite の dev server で `http://localhost:{port}/assets/preview.html` としてアクセス可能
- 本番ビルドにも含まれる（public/ 配下のため）。不要なら `.gitignore` に追加を案内
