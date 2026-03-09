---
name: gen-particles
description: パーティクルエフェクトの設計・生成・プレビュー・コード組み込みを自動化
model: opus
user_invocable: false
---

# Gen Particles

パーティクルエフェクトを設計・生成し、プロジェクトに組み込むスキル。
Canvas 2D でリアルタイムプレビューし、確定後にプロジェクトのエフェクトエンジンに反映する。

> **使い分け**:
> `/asset` → 画像 — 画像アセット生成（ローカル FLUX.1）
> `/asset` → 音源 — フリー BGM・SE 取得（Web）
> `/asset` → パーティクル — パーティクルエフェクト生成（コード）

---

## 0. プロジェクト分析

### 0-1. 情報収集（並列実行）

以下を並列で実行:

- CLAUDE.md を Read — 技術スタック・テーマを把握
- `src/` 配下で `particle`, `effect`, `emitter`, `spawn` を Grep — 既存エフェクトシステムを特定
- `public/assets/sprites/effects/` を Glob — 既存テクスチャの棚卸し
- `public/assets/preview.html` を Read — 既存デモセクションの有無を確認

### 0-2. エフェクトエンジン検出

プロジェクトのエフェクト実装方式を判定する:

| パターン | 判定基準 | 対応 |
|---------|---------|------|
| **PixiJS + EffectsController** | `src/engine/pixi/EffectsController.ts` が存在 | 既存 EmitterConfig 体系に追加 |
| **Canvas 2D 自前実装** | Canvas パーティクルコードが存在 | 既存パターンに従う |
| **ライブラリなし** | エフェクトコードが存在しない | Canvas 2D で新規構築 |

### 0-3. 既存エフェクト一覧

検出したエフェクトエンジンから、定義済みエフェクトの一覧を表示:

```
## 既存エフェクト

| # | エフェクト名 | 構成 | 用途 |
|---|------------|------|------|
| 1 | fire | 2層（炎 + 火花） | 火魔法 |
| 2 | frost | 2層（氷結晶 + 雪粒） | 氷魔法 |
| ... | ... | ... | ... |
```

---

## 1. エフェクト設計

### 1-1. ユーザーに確認

AskUserQuestion で確認:

**質問: どんなエフェクトを作りますか？**
- 自由入力（例: 「雷魔法」「回復エフェクト」「バフ付与」「炎の壁」）

### 1-2. EmitterConfig 設計

ユーザーの要望をもとに、エフェクトの EmitterConfig を設計する。

#### パラメータ体系

```typescript
interface EmitterConfig {
  count: number              // パーティクル生成数（5〜50）
  color: number | number[]  // カラー（16進数 or 配列）
  speed: number              // 初期速度（0.5〜8）
  speedVariance?: number     // 速度ランダム幅
  lifetime: number           // ライフタイム/フレーム（10〜80）
  lifetimeVariance?: number  // ライフタイムランダム幅
  size: number              // 開始サイズ（1〜10）
  sizeEnd?: number          // 終了サイズ
  sizeVariance?: number     // サイズランダム幅
  gravity: number            // 重力（負=上昇, 正=下降）
  friction?: number          // 減衰率（0.90〜0.99）
  spread: number            // 放射角度（ラジアン）
  direction?: number        // 基準方向（ラジアン）
  shape?: 'circle' | 'square' | 'diamond' | 'star'
  trail?: boolean           // トレイル（残像）
  rotationSpeed?: number    // 回転速度
  rotationVariance?: number // 回転ランダム幅
  emitRadius?: number       // 発生位置のランダム半径
}
```

#### 設計ガイドライン

| エフェクト系統 | 推奨パラメータ |
|--------------|--------------|
| **火・爆発系** | gravity: -0.1〜-0.15, friction: 0.96, shape: circle, 暖色系 |
| **氷・水系** | gravity: 0.02, friction: 0.98, shape: diamond, 寒色系, rotationSpeed あり |
| **光・聖系** | gravity: -0.02, shape: star, 金・白系, sizeEnd > size（拡大） |
| **毒・闇系** | gravity: -0.06, shape: circle, 紫系, emitRadius あり |
| **雷系** | speed: 6+, lifetime: 短め(10-20), shape: square, 黄・白, friction: 0.92 |
| **回復系** | gravity: -0.08, shape: star, 緑・白, sizeEnd > size, emitRadius あり |
| **バフ系** | 上昇パーティクル + リング構成, shape: star/diamond |

#### 多層構成

エフェクトは **1〜3層** で構成する（既存パターンに合わせる）:

- **第1層**: メインエフェクト（パーティクル数多め）
- **第2層**: サブエフェクト（火花・残光・雪粒など）
- **第3層**: 余韻（残火・散らばる破片など、任意）

---

## 2. プレビュー

### 2-1. preview.html のデモセクション更新

`public/assets/preview.html` の PARTICLE DEMO セクションに、新しいエフェクトのボタンを追加する。

#### ボタン追加

```html
<button data-fx="{エフェクト名}" style="--btn-color:{テーマカラー}">{表示名}</button>
```

#### JS にエフェクト関数を追加

既存の `effects` オブジェクトに新しいエフェクト関数を追加:

```javascript
effects.{エフェクト名} = function() {
  spawn(CX, CY, { /* 第1層の EmitterConfig */ });
  spawn(CX, CY, { /* 第2層の EmitterConfig */ });
  flash({フラッシュカラー});
};
```

### 2-2. ブラウザでプレビュー

1. Playwright で preview.html を開く
2. 新しいエフェクトボタンをクリック
3. スクリーンショットを `check_log/screenshots/` に保存
4. ユーザーに確認

**質問: このエフェクトでOKですか？**
- OK → ステップ 3 へ
- 調整したい → パラメータを修正して再プレビュー（最大3回）
- やり直し → ステップ 1 に戻る

---

## 3. エフェクト定義の追加

エフェクトエンジンの種類に応じて定義を追加する。

### 3-A. PixiJS + EffectsController パターン

#### MAGIC_EMITTERS に追加

`src/engine/pixi/EffectsController.ts` の `MAGIC_EMITTERS` に新エフェクトを追加:

```typescript
const MAGIC_EMITTERS: Record<string, EmitterConfig[]> = {
  // 既存...
  {新エフェクト名}: [
    { /* 第1層 */ },
    { /* 第2層 */ },
  ],
}
```

#### 専用メソッドの追加（必要な場合）

魔法エフェクト以外（バフ・回復・特殊演出など）の場合は、EffectsController に専用メソッドを追加:

```typescript
spawn{エフェクト名}(x: number, y: number): void {
  this.spawnBurst(x, y, { /* config */ });
}
```

#### テクスチャの追加（任意）

エフェクトに固有のテクスチャが必要な場合:
1. `/asset` → 画像 でテクスチャ画像を生成
2. `public/assets/sprites/effects/` に配置
3. `EFFECT_TEXTURE_PATHS` に追加

#### カラー定数の追加

`src/engine/pixi/types.ts` の `MAGIC_COLORS` にカラーを追加:

```typescript
export const MAGIC_COLORS: Record<string, number> = {
  // 既存...
  {新エフェクト名}: 0x{カラーコード},
}
```

`BattleRenderer.ts` の `MAGIC_FLASH_COLORS` にもフラッシュカラーを追加:

```typescript
const MAGIC_FLASH_COLORS: Record<string, number> = {
  // 既存...
  {新エフェクト名}: 0x{フラッシュカラー},
}
```

### 3-B. Canvas 2D 自前実装パターン

既存のパーティクル描画コードに合わせてエフェクト関数を追加。
パターンは preview.html のデモ JS と同じ構造を使う。

### 3-C. エフェクトエンジンなしパターン

最小限の Canvas 2D パーティクルシステムを新規構築:

1. `src/engine/particles/` ディレクトリを作成
2. `ParticleSystem.ts` — パーティクル管理（spawn/update/draw）
3. `effects.ts` — エフェクト定義
4. 使用箇所のコンポーネントに Canvas + useEffect で統合

---

## 4. コード適用

追加したエフェクトをアプリケーションコードに接続する。

### 4-1. 適用先の特定

Grep で既存のエフェクト呼び出しパターンを検索:
- `spawnMagic`, `spawnBurst`, `executeTurnAnimation`, `magicType`, `action:`
- コンポーネント側: `BattleRenderer`, `BattleCanvas`, `BattleAnimation`

### 4-2. 適用

エフェクトエンジンの種類に応じて接続:

**PixiJS + EffectsController:**
- 既存アクション（magic 等）で使う場合 → `magicType` に紐づけるだけでOK
- 新しいアクションタイプの場合 → `BattleRenderer.ts` の `executeTurnAnimation` に分岐を追加

**Canvas 2D / エンジンなし:**
- 使用箇所のコンポーネントからエフェクト関数を呼び出すコードを追加

### 4-3. 適用ルール

- **既存のエフェクト呼び出しパターンがあれば必ずそれに従う**（独自実装しない）
- **型定義との整合性**: EmitterConfig の型、アクションタイプの union 型を確認
- **参照パスの一致**: テクスチャを追加した場合、コード内のパスと配置先が一致すること

---

## 5. テスト（任意）

既存のユニットテストパターンがある場合のみ:

- 新エフェクトの EmitterConfig が正しい型か確認
- spawn メソッドが正常に呼び出されるか確認

テストファイルのパターンは既存テスト（`src/test/unit/effectsController.unit.test.ts` 等）に従う。

---

## 6. 完了報告

```
## Gen Particles 完了

| # | エフェクト名 | 構成 | カラー | 用途 |
|---|------------|------|--------|------|
| 1 | {名前} | {N}層 | {カラー説明} | {用途} |

- EffectsController: 更新済み
- preview.html: デモボタン追加済み
- types.ts: カラー定数追加済み
```

---

## 7. アセットプレビュー更新

Task（subagent_type: asset-preview）を起動し、`public/assets/preview.html` を再生成する。

---

## 制約事項

- **パーティクル上限**: 1エフェクトあたり最大150パーティクル（パフォーマンス制約）
- **形状は4種**: circle / square / diamond / star（カスタム形状は非対応）
- **テキスト描画不可**: パーティクルでテキストは表現できない
- **テクスチャは任意**: テクスチャなしでも Graphics 描画で十分な表現が可能

## 禁止事項

- 既存エフェクトの上書き・削除（追加のみ）
- パーティクル上限（150）を超える設定
- パフォーマンスに影響する無限ループや過剰な trail 設定
