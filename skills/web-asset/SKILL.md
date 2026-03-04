---
name: web-asset
description: 画像・SE・BGMのフリーアセットを調査・取得・クレジット管理まで自動化
model: opus
user_invocable: true
---

# Asset Hunt

フリーアセット（画像・アイコン・SE・BGM）の調査→比較提示→ダウンロード→配置→クレジット管理を自動化するスキル。
アプリ・Webサービス・ランディングページなど用途を問わず使える。

## 0. プロジェクト分析と推奨提案

プロジェクトを分析し、不足アセットを特定して推奨を提案する。

### 0-1. プロジェクト情報の収集（並列実行）

以下を並列で実行:

- CLAUDE.md を Read — 技術スタック・テーマ・用途を把握
- `docs/CORE.md` または `docs/ARCHITECTURE.md` を Read — コンセプト・ターゲットユーザーを把握（なければスキップ）
- `public/assets/` と `src/assets/` を Glob — 既存アセットの棚卸し
- `src/` 配下で画像・音声の import/参照を Grep — コードが参照しているアセットパスを特定
- `CREDITS.md` を Read — 既に取得済みのアセットを把握（なければスキップ）

### 0-2. ギャップ分析

収集した情報から以下を判定:

- **プロジェクトの種別・用途**（Webアプリ、モバイルアプリ、LP、業務ツール等）
- **既存アセットのスタイル**（サイズ、色調、トーン）
- **コードが参照しているが存在しないアセット**（404候補）
- **不足している種別**（画像はあるがSE/BGMがない等）
- **スタイル統一性**（既存アセットと合わないものを避ける）

### 0-3. 推奨提案

分析結果をもとに、具体的な推奨を提示する:

```
## プロジェクト分析結果

- 種別: {判定結果}（Webアプリ / モバイル / LP 等）
- テーマ: {雰囲気・トーン}
- 既存アセット: 画像 {N}件 / SE {N}件 / BGM {N}件
- スタイル: {既存アセットの特徴}

## 推奨アセット

| # | 種別 | 推奨内容 | 理由 |
|---|------|---------|------|
| 1 | {種別} | {具体的な内容} | {なぜ必要か} |
| 2 | {種別} | {具体的な内容} | {なぜ必要か} |
| 3 | {種別} | {具体的な内容} | {なぜ必要か} |
```

AskUserQuestion で確認:

**質問: どのアセットを取得しますか？**（multiSelect: true）
- 推奨候補を選択肢として提示（上位3-4件）
- 各選択肢の description に理由を記載

ユーザーの選択を受けて、**選択された全アセットに対しステップ 1〜7 をループ実行する**。
各アセットごとに独立して調査→取得→クレジット更新を行い、完了報告はまとめて最後に出す。

---

## 1. 配置先パスの決定

ステップ 0 で種別が決まった状態で:

1. ステップ 0 で取得した既存アセットのディレクトリ構造を参照
2. **既存構造があればそれに従う**（例: `public/assets/se/` が既にあればそこに配置）
3. **既存構造がなければ `public/assets/` に配置**
4. ディレクトリが存在しなければ `mkdir -p` で作成

---

## 2. 調査先の選定

種別に応じて調査先を切り替える:

### 画像（イラスト・アイコン・ドット絵）
1. **Kenney.nl** — 高品質CC0、UIアセット・アイコン豊富、直接DL可
   - URL: `https://kenney.nl/assets?q={query}`
2. **OpenGameArt.org** — CC0多数、2Dアート全般
   - URL: `https://opengameart.org/art-search-advanced?keys={query}&field_art_type_tid[]=9` (2D Art)
3. **itch.io** — 量が圧倒的、ライセンス明記のもののみ
   - URL: `https://itch.io/game-assets/tag-{query}`

### SE（効果音）
1. **効果音ラボ** — 日本語、商用OK、クレジット不要、ログイン不要
   - URL: `https://soundeffect-lab.info/sound/anime/` 等カテゴリページから探す
   - 検索クエリは日本語で実行
2. **魔王魂** — 日本語、商用OK、会員登録不要
   - URL: `https://maou.audio/category/se/`
   - 検索クエリは日本語で実行
3. **Kenney.nl** — 高品質CC0アセット
   - URL: `https://kenney.nl/assets?q={query}`
4. **OpenGameArt.org** — CC0/CC-BY多数
   - URL: `https://opengameart.org/art-search-advanced?keys={query}&field_art_type_tid[]=13` (Sound Effect)
5. **Freesound.org** — 要APIキー認証（セットアップ済みの場合のみ）
   - API: `https://freesound.org/apiv2/search/text/?query={query}&token={api_key}`
   - 認証セットアップは「認証付きソース」セクション参照
   - 未認証ならスキップ

### BGM
1. **魔王魂** — 日本語、商用OK、会員登録不要
   - URL: `https://maou.audio/category/bgm/`
   - 検索クエリは日本語で実行
2. **DOVA-SYNDROME** — 日本語、商用OK、ログイン不要
   - URL: `https://dova-s.jp/_contents/search/?keyword={query}`
   - 検索クエリは日本語で実行
3. **OpenGameArt.org** — CC0/CC-BY多数
   - URL: `https://opengameart.org/art-search-advanced?keys={query}&field_art_type_tid[]=12` (Music)
4. **Kenney.nl** — CC0
   - URL: `https://kenney.nl/assets?q={query}`
5. **Freesound.org** — 要APIキー認証（セットアップ済みの場合のみ）
   - API: `https://freesound.org/apiv2/search/text/?query={query}&filter=type:music&token={api_key}`
   - 未認証ならスキップ

### 共通
- WebSearch も併用して最新のアセットパックを探す
- **WebSearch経由のDL制限**: WebSearchで見つけた未知ドメインのURLからは直接DLしない。上記の指定サイト以外のURLは手動DL案内に切り替える
- 海外サイトの検索クエリは英語に変換して実行する（日本語の用途説明は英語キーワードに翻訳）
- 日本語サイト（魔王魂・効果音ラボ・DOVA-SYNDROME）は日本語クエリで検索
- **同作者優先**: CREDITS.md に既に登録されている作者のアセットを優先的に探す（スタイル統一に有効）

---

## 3. ライセンス確認

各候補について以下を確認:

- **CC0 (Public Domain)** → 最優先。制限なし
- **CC-BY** → 利用可。クレジット表記必須
- **CC-BY-SA** → 利用可だがSA条件を警告
- **OGA-BY** → OpenGameArt固有。CC-BY相当
- **MIT / Apache 2.0** → 利用可
- **GPL** → 警告（コード全体への影響あり）
- **ライセンス不明** → スキップ。候補から除外

---

## 4. 候補の比較提示

調査結果を以下のフォーマットで提示する:

```
## 調査結果: {種別} - {用途}

| # | アセット名 | ソース | ライセンス | 形式 | プレビュー |
|---|-----------|--------|-----------|------|-----------|
| 1 | {name}    | OpenGameArt | CC0 | PNG 16x16 | [見る/聴く]({preview_url}) |
| 2 | {name}    | Kenney | CC0 | PNG 32x32 | [見る/聴く]({preview_url}) |
| 3 | {name}    | itch.io | CC-BY | PNG 16x16 | [見る/聴く]({preview_url}) |

### 推奨: #{番号} {アセット名}
- 理由: {推奨理由}
```

プレビューURLの取得方法:
- **画像**: アセットページのサムネイル画像URL、またはアセットページ自体のURL
- **SE/BGM**: アセットページの試聴プレイヤーがあるページURL

**リンクを踏んで目視/試聴してから選んでもらう。**

AskUserQuestion で選択を求める:

**質問: どのアセットを使用しますか？**（リンクで確認してから選んでください）
- 候補1: {アセット名}（{ライセンス}）
- 候補2: {アセット名}（{ライセンス}）
- 候補3: {アセット名}（{ライセンス}）
- 再検索（キーワードを変えて再調査）

### 再検索の戦略

「再検索」が選ばれた場合、以下の順で検索を拡張する:

1. **同義語展開** — 元のクエリの類義語・関連語で再検索（例: notification → alert, chime）
2. **抽象度変更** — より広い/狭いカテゴリで検索（例: button_click → ui_sound → interaction）
3. **日本語↔英語切替** — 海外サイトで日本語クエリの英訳バリエーション、日本語サイトで和訳バリエーション
4. **ソース切替** — 前回検索しなかったサイトを優先的に探す

---

## 5. 取得・配置

### 5-A. 既存アセットを選んだ場合

1. **直接DL可能か確認**
   - Kenney.nl: アセットページから直接ZIPダウンロード可能な場合が多い
   - OpenGameArt: ファイルダウンロードリンクを取得
   - itch.io: 無料アセットの直接DLリンクを取得
   - **直接DL不可** → URLを提示し、手動DLを案内して終了

2. **ダウンロード実行**
   - `curl -L -o {filename} {url}` でダウンロード
   - ZIPの場合は以下の安全手順で展開:
     1. `unzip -l {zip} | grep '\.\.\/'` でパストラバーサルを検知 → ヒットしたら展開中止・警告
     2. `unzip {zip} -d /tmp/asset-extract/` で一時ディレクトリに隔離展開
     3. `find /tmp/asset-extract/ -type l` でシンボリックリンクを検知 → あれば該当ファイル削除
     4. 必要なファイルだけプロジェクトにコピー

3. **配置**
   - ステップ 1 で決定したパスにファイルを配置
   - 必要に応じてリネーム（スネークケース、用途がわかる名前）
   - 不要なファイル（README、サンプル等）は除外

4. **確認**
   - 配置したファイルを `ls -la` で確認
   - 画像の場合は Read ツールでプレビュー表示

## 5-B. アセット変換・加工（必要な場合のみ）

取得したアセットがプロジェクトの要件と合わない場合、以下を実行:

1. **形式変換**
   - 画像: `magick convert {input} {output}` （ImageMagick）
   - 音声: `ffmpeg -i {input} {output}` （FFmpeg）
   - 例: SVG→PNG、WAV→OGG、MP3→OGG

2. **リサイズ・解像度統一**
   - 既存アセットのサイズに合わせてリサイズ
   - `magick convert {input} -resize {W}x{H} {output}`
   - ドット絵の場合は `-filter Point` でニアレストネイバー

3. **画像の切り出し**
   - 必要な部分だけ切り出す
   - `magick convert {input} -crop {W}x{H}+{X}+{Y} {output}`

4. **ツール未インストール時**
   - ImageMagick / FFmpeg が見つからない場合は手動変換を案内して続行

---

## 6. CREDITS.md 更新

プロジェクトルートの `CREDITS.md` を更新する（存在しなければ新規作成）:

### フォーマット

```markdown
# Credits

## Assets

### Images
- **{アセット名}** by {作者名}
  - Source: {URL}
  - License: {ライセンス種別}
  - Used in: {用途の説明}

### Sound Effects
- **{アセット名}** by {作者名}
  - Source: {URL}
  - License: {ライセンス種別}
  - Used in: {用途の説明}

### Music
- **{アセット名}** by {作者名}
  - Source: {URL}
  - License: {ライセンス種別}
  - Used in: {用途の説明}
```

- 既存エントリと重複しないよう **Source URL ベースで確認**（同じURLがあれば重複とみなしスキップ）
- カテゴリ（Sprites / Sound Effects / Music）ごとにグループ化
- CC-BY等クレジット必須ライセンスは太字で強調

---

## 7. 完了報告

複数アセットを取得した場合はまとめて報告する:

```
## Asset Hunt 完了

| # | 種別 | アセット | 作者 | ライセンス | 配置先 |
|---|------|---------|------|-----------|--------|
| 1 | {種別} | {アセット名} | {作者名} | {ライセンス} | {パス} |
| 2 | {種別} | {アセット名} | {作者名} | {ライセンス} | {パス} |

- CREDITS.md: 更新済み
```

---

## 信頼性チェック

候補選定時に以下を確認し、信頼性が低いものは候補から除外する:

- **DL数・評価** — ダウンロード数や評価が高いアセットを優先（実績 = 信頼性）
- **作者の実績** — プロフィール・他作品を確認。複数作品を公開している作者を優先
- **itch.io** — ライセンスが明記されているもののみ対象。「Free」でもライセンス未記載はスキップ（無料DL ≠ 自由に使える）
- **盗作リスク** — アセットページのコメント欄や説明文に権利問題の指摘がないか確認
- **同作者・同パック優先** — CREDITS.md に既登録の作者やアセットパックがあれば、同じ作者の別アセットを優先候補にする（スタイル統一・ライセンス確認の手間削減）

## 制約事項

- **ログイン不要のソースが基本** — ログインが必要なサイトはスキップ。ただし認証セットアップ済みのソース（Freesound等）は利用可
- **直接DLできないURLはスキップ** — 手動DL案内に切り替え
- **ライセンス不明はスキップ** — 候補から除外し理由を表示
- **商用利用不可ライセンスは警告** — NC付きは明示的に警告
- **ファイルサイズ制限** — 単一ファイル10MB超は警告
- **形式の優先順位** — 画像: PNG > SVG > GIF > WEBP、SE: WAV > OGG > MP3、BGM: OGG > MP3 > WAV

## 認証付きソース

### Freesound.org（初回セットアップ）

認証情報は `~/.claude/credentials/asset-auth.json` に保存する。

**初回利用時の手順:**

1. `~/.claude/credentials/asset-auth.json` を Read して認証情報の有無を確認
2. 認証情報がなければ、以下をユーザーに案内:
   ```
   Freesound.org のAPIキーが未設定です。セットアップしますか？

   1. https://freesound.org/apiv2/apply/ にアクセス
   2. アカウント作成（未登録の場合）
   3. 「Apply for API key」でアプリ名・説明を入力
   4. 発行された API Key をここに貼り付けてください
   ```
3. AskUserQuestion でAPIキーを入力してもらう（「スキップ」選択肢も用意）
4. 入力されたら `~/.claude/credentials/asset-auth.json` に保存:
   ```json
   {
     "freesound": {
       "api_key": "{入力されたキー}",
       "setup_date": "{YYYY-MM-DD}"
     }
   }
   ```
5. `mkdir -p ~/.claude/credentials` を事前に実行
6. プロジェクトの `.gitignore` に `credentials/` が含まれていることを確認（なければ警告）

**利用時の手順:**

1. `~/.claude/credentials/asset-auth.json` を Read
2. `freesound.api_key` が存在すればAPI経由で検索・DL
3. 存在しなければ Freesound をスキップ（他のソースで続行）

**APIの使い方:**
- 検索: `https://freesound.org/apiv2/search/text/?query={query}&token={api_key}`
- DL: `https://freesound.org/apiv2/sounds/{id}/download/?token={api_key}`
- プレビュー: レスポンスの `previews.preview-hq-mp3` フィールド

---

## 禁止事項

- 著作権が不明なアセットのダウンロード
- ライセンス条件を無視したクレジット省略
- 有料アセットの無断使用
- APIキーが必要なサービスへの認証なしアクセス
