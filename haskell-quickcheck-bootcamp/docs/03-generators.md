# 🎲 第3章 ジェネレータ入門（Example 23–30）

## この章のゴール

「入力をどう作るか」を自分で制御できるようになります。

## Arbitrary と Gen

```haskell
class Arbitrary a where
  arbitrary :: Gen a        -- 値を1つ作る方法
  shrink    :: a -> [a]     -- 失敗したときに小さくする方法（第5章）
```

`Gen a` は「`a` をランダムに作る方法」を表す型です。
実行せずに組み立てられる「レシピ」だと思ってください。

## 中身を覗く道具

```haskell
generate :: Gen a -> IO a            -- 1つ取り出す
sample   :: Show a => Gen a -> IO () -- 11 個表示する
sample'  :: Gen a -> IO [a]          -- 11 個リストで返す
```

**自作の生成器を書いたら、必ず `sample'` で目視してください。**

## 基本部品

| API | 役割 |
|---|---|
| `choose (lo, hi)` | 閉区間から一様に選ぶ（両端を含む） |
| `chooseInt (lo, hi)` | `Int` 専用。少し速い |
| `elements [a,b,c]` | リストから一様に選ぶ（空リストは実行時エラー） |
| `oneof [g1,g2]` | 生成器から等確率で選ぶ |
| `frequency [(3,g1),(1,g2)]` | 重み付きで選ぶ |
| `listOf g` / `listOf1 g` | リスト／空でないリスト |
| `vectorOf n g` | 長さちょうど n |
| `shuffle xs` | 並べ替え（順列が欲しいとき） |
| `sublistOf xs` | 各要素を 50% で採用した部分リスト |
| `infiniteListOf g` | 無限リスト |
| `growingElements xs` | サイズに応じて後ろの要素も選ばれるようになる |

## 原則：「弾く」より「作る」

```haskell
-- 遅い・偏る
genEven = arbitrary `suchThat` even

-- 速い・確実
genEven = (* 2) <$> arbitrary
```

`suchThat` は「ほとんどの値が条件を満たす」ときだけ使ってください。
条件を満たす確率が 1/10 を切るなら、生成器を書き直すべきです。

固まらない版として `suchThatMaybe`（有限回で諦めて `Nothing`）もあります。

## Gen は Monad

| 場面 | 書き方 |
|---|---|
| 値を変換する | `fmap f g` / `f <$> g` |
| 独立な値を並べる | `C <$> g1 <*> g2` |
| **あとの値が前の値に依存する** | `do` 記法 |

依存があるのに Applicative で無理に書くと、`suchThat` で弾く羽目になります。

```haskell
-- 「x 以上の y」は do でしか書けない
genOrderedPair = do
  x <- choose (0, 100)
  y <- choose (x, 100)
  return (x, y)
```

## サイズパラメータ

QuickCheck は生成器に「サイズ」を渡しています。0 から `maxSize`（既定 100）まで増えていきます。

| API | 役割 |
|---|---|
| `sized (\n -> ...)` | 現在のサイズを使う |
| `getSize` | サイズそのものを取り出す |
| `resize n g` | サイズを固定する |
| `scale f g` | サイズを関数で変換する |

サイズの意味は型ごとに違います。`Int` なら値の大きさ、リストなら長さ、というのが目安です。

## Example 一覧

| # | 内容 |
|---|---|
| [23](../examples/Example23.hs) | `Arbitrary` クラス、`generate` / `sample` / `sample'` |
| [24](../examples/Example24.hs) | `choose` / `elements` / `forAll` |
| [25](../examples/Example25.hs) | `oneof` / `frequency`。実務的な HTTP リクエスト生成 |
| [26](../examples/Example26.hs) | リストの生成（`listOf` / `vectorOf` / `shuffle` / `sublistOf`） |
| [27](../examples/Example27.hs) | `suchThat` の危険と正しい代替 |
| [28](../examples/Example28.hs) | Functor / Applicative / Monad としての `Gen` |
| [29](../examples/Example29.hs) | `sized` / `resize` / `scale` |
| [30](../examples/Example30.hs) | **生成器そのものをテストする** |

## 最重要：生成器をテストする

生成器が壊れていると、テストは「通るのにバグを見逃す」状態になります。
これは一番たちの悪い失敗です。

```haskell
prop_genIsValid :: Property
prop_genIsValid = forAll myGen validityCheck
```

ただし、これだけでは足りません。
「常に空リストを返す生成器」も、たいていの不変条件を満たしてしまいます。

生成器のチェックリスト：
1. 不変条件をプロパティで書く
2. `sample'` で実際の値を**目で見る**
3. 長さや値の範囲が偏っていないか確認する
4. `classify` / `tabulate` で分布を測る（第7章）

## 次へ

→ [第4章 自作型の生成器](./04-custom-generators.md)
