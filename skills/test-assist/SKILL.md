---
name: test-assist
description: 自然言語からPlaywrightテスト自動生成。テストしたい操作を日本語で言うだけでE2Eテストコードを生成する
tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_snapshot, mcp__plugin_playwright_playwright__browser_click, mcp__plugin_playwright_playwright__browser_type, mcp__plugin_playwright_playwright__browser_fill_form, mcp__plugin_playwright_playwright__browser_select_option, mcp__plugin_playwright_playwright__browser_press_key, mcp__plugin_playwright_playwright__browser_wait_for, mcp__plugin_playwright_playwright__browser_take_screenshot, mcp__plugin_playwright_playwright__browser_close
user_invocable: true
---

# /test-assist — 自然言語からPlaywrightテスト自動生成

「テストしたい操作を日本語で言うだけ」でE2Eテストコードを生成するスキル。
操作を再現→検証→テストコード化まで一貫して行い、以降 `.cc` や `.tck` で自動実行される。

---

## フロー概要

```
Phase 1: ヒアリング → Phase 2: 開始URL特定 → Phase 3: セットアップ確認
→ Phase 4: 操作再現と記録 → Phase 5: テストコード生成
→ Phase 6: テスト実行・検証 → Phase 7: 完了報告
```

---

## Phase 1: ヒアリング

以下のメッセージを表示して **停止** する（AskUserQuestion を使う）:

> どの操作をテストしたいですか？
> 日本語で操作フローを記述してください。
> 例：「決済ボタンを押したら確認画面が出て、確定したら完了画面に遷移する」

ユーザーの回答を受け取ったら Phase 2 へ進む。

---

## Phase 2: 開始URL特定

以下の優先順で開始URLを決定する:

1. ユーザーの説明にURLが含まれていればそれを使う
2. URLがなければ AskUserQuestion で聞く:
   > 開始ページのURLを教えてください（省略で自動検出します）
3. 省略された場合:
   - プロジェクトの CLAUDE.md からポート情報を読み取る
   - 見つからなければポートスキャン: `3000, 5500, 5173, 8080, 8788, 8000, 4200, 80` の順に接続テスト
   - `curl -s -o /dev/null -w "%{http_code}" http://localhost:{port}` で 200系を返すポートを使用
   - 見つからなければエラー報告して終了

---

## Phase 3: セットアップ確認

以下を順にチェックし、不足があれば自動でセットアップする:

| チェック項目 | なければ |
|------------|---------|
| `package.json` | `npm init -y` |
| `@playwright/test` in devDependencies | `npm install -D @playwright/test && npx playwright install chromium` |
| `playwright.config.ts` | 最小構成で **新規作成**（既存があれば触らない） |
| `tests/test-assist/` ディレクトリ | `mkdir -p tests/test-assist` |

### 最小 playwright.config.ts

既存の `playwright.config.ts` がない場合のみ作成する:

```typescript
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests/test-assist',
  timeout: 30_000,
  retries: 1,
  use: {
    baseURL: 'http://localhost:{port}',
    headless: true,
    screenshot: 'only-on-failure',
  },
});
```

`{port}` は Phase 2 で特定したポート番号に置換する。

**重要**: 既存の `playwright.config.ts` がある場合は一切変更しない。`tests/test-assist/` がtestDirに含まれているか確認し、含まれていなければテスト実行時にconfigを明示的に指定する。

---

## Phase 4: 操作再現と記録

MCP ツールで操作を再現しながら、各ステップを内部的に記録する。

### 操作手順

1. `browser_navigate` で開始URLへ移動
2. `browser_snapshot` でアクセシビリティツリーを取得
3. ユーザーの説明に沿って操作を実行（click, type, wait_for 等）
4. 各操作後に `browser_snapshot` で次の操作対象を特定
5. 最終状態で期待結果を確認

### 内部記録フォーマット

各操作を以下の形式で記録する（テストコード生成に使用）:

```
{ action: 'navigate', url: '/path' }
{ action: 'click', role: 'button', name: '決済する' }
{ action: 'fill', label: 'メールアドレス', value: 'test@example.com' }
{ action: 'selectOption', label: '都道府県', value: '東京都' }
{ action: 'pressKey', key: 'Enter' }
{ action: 'expectVisible', text: '確認画面' }
{ action: 'expectURL', pattern: '/confirm' }
{ action: 'expectHidden', text: 'ローディング' }
```

### セレクタ戦略（安定性優先順）

MCP の `ref`（s1e5 等）は一時IDなのでテストコードに使えない。snapshot の情報から安定セレクタを構築する:

1. `getByRole('button', { name: '決済する' })` — ロール + 名前
2. `getByText('確認画面')` — テキスト
3. `getByLabel('メールアドレス')` — フォームラベル
4. `getByPlaceholder('example@mail.com')` — プレースホルダー
5. `getByTestId('payment-btn')` — data-testid
6. `locator('.submit-btn')` — CSS（最終手段）

### エラー時

- 要素が見つからない → snapshot 再取得、3回失敗でユーザーに報告して中断
- サーバー未起動 → 即座に「サーバーが起動していません」と報告して終了

---

## Phase 5: テストコード生成

### MCP → Playwright Test API マッピング

| MCP ツール | 生成コード |
|-----------|-----------|
| `browser_navigate(url)` | `await page.goto('{path}')` |
| `browser_click(ref)` | `await page.getByRole('{role}', { name: '{name}' }).click()` |
| `browser_type(ref, text)` | `await page.getByLabel('{label}').fill('{text}')` |
| `browser_fill_form(fields)` | 各フィールドを `page.getByLabel().fill()` に展開 |
| `browser_select_option(ref, values)` | `await page.getByLabel('{label}').selectOption('{value}')` |
| `browser_press_key(key)` | `await page.keyboard.press('{key}')` |
| `browser_wait_for(text)` | `await expect(page.getByText('{text}')).toBeVisible()` |
| `browser_wait_for(textGone)` | `await expect(page.getByText('{text}')).toBeHidden()` |

### アサーション生成

ユーザーの説明から期待結果を抽出してアサーションを生成する:

- 「〜画面に遷移する」→ `await expect(page).toHaveURL(/pattern/)`
- 「〜が表示される」→ `await expect(page.getByText('...')).toBeVisible()`
- 「〜が消える」→ `await expect(page.getByText('...')).toBeHidden()`

### テストファイルテンプレート

```typescript
import { test, expect } from '@playwright/test';

test('{ユーザーの説明そのまま}', async ({ page }) => {
  // Step 1: ページに移動
  await page.goto('{path}');

  // Step 2: {操作の説明}
  await page.getByRole('button', { name: '{name}' }).click();

  // Step 3: {期待結果}
  await expect(page.getByText('{expected}')).toBeVisible();
});
```

### 命名規則

- **ファイル名**: 日本語を英語 kebab-case に要約（例: `payment-confirmation.spec.ts`）
- **test() 名**: ユーザーの日本語説明をそのまま使用

---

## Phase 6: 生成テスト実行

```bash
npx playwright test tests/test-assist/{filename} --reporter=list
```

- **PASS** → Phase 7 へ
- **FAIL** → セレクタやタイミングを修正して再実行（最大2回リトライ）
- 2回リトライ後も FAIL → エラー内容をユーザーに報告し、ファイルは残す（手動修正可能）

---

## Phase 7: 完了報告

以下のフォーマットで報告する:

```
## /test-assist 完了
- テスト名: {テスト名}
- ファイル: tests/test-assist/{filename}
- 操作ステップ: {N}ステップ
- アサーション: {M}個
- 実行結果: PASS

.cc および .tck で自動チェックされます。
```

---

## 禁止事項

- ユーザーの説明にない操作を追加しない
- `page.waitForTimeout()` 等のハードコード待機を使わない（`expect().toBeVisible()` の自動リトライを使う）
- XPath セレクタを使わない
- テストデータを勝手に本番DBに書き込まない
