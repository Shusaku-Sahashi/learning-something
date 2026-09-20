# 🏗 第4章 自作型の生成器（Example 31–46）

## この章のゴール

自分のデータ型を、正しく・意味のある分布で生成できるようになります。

## 基本の型

```haskell
-- 積型
instance Arbitrary Point where
  arbitrary = Point <$> arbitrary <*> arbitrary

-- 範囲を絞る
instance Arbitrary Screen where
  arbitrary = Screen <$> choose (0, 1919) <*> choose (0, 1079)

-- 列挙型（Enum + Bounded なら1行）
instance Arbitrary Role where
  arbitrary = arbitraryBoundedEnum

-- 和型
instance Arbitrary Shape where
  arbitrary = oneof [ Circle <$> arbitrary, Rect <$> arbitrary <*> arbitrary ]
```

`deriving (Show)` を忘れると、反例を表示できないのでコンパイルが通りません。

## 鉄則1：再帰的な型は必ず `sized` で書く

素朴に書くと停止しません。

```haskell
-- ★ 危険：メモリを食いつぶして固まる
genTree = oneof [ pure Leaf, Node <$> genTree <*> arbitrary <*> genTree ]

-- ○ 正しい
genTree = sized go
  where
    go 0 = pure Leaf
    go n = frequency
      [ (1, pure Leaf)
      , (3, Node <$> go (n `div` 2) <*> arbitrary <*> go (n `div` 2))
      ]
```

`frequency` で `Leaf` を選びやすくするだけでは不十分です。
平均的には止まっても、運悪く巨大な木を引く可能性が残ります。

### サイズの配り方

| 形 | 配り方 |
|---|---|
| 1項演算 `Neg e` | `go (n - 1)` |
| 2項演算 `Add a b` | `go (n `div` 2)` を2回 |
| k 個の子 `List [..]` | `go (n `div` (k + 1))` を k 回 |

「子のサイズの合計が親より小さい」ようにするのがポイントです。

## 鉄則2：不変条件はスマートコンストラクタで満たす

| 方法 | 評価 |
|---|---|
| スマートコンストラクタを通す | ◎ 一番簡単で確実 |
| 構造的に正しいものを直接組み立てる | ○ ただし偏りに注意 |
| 生成してから `suchThat` で弾く | △ 最後の手段。遅いうえに偏る |

Example 35 では、「差分を積み上げる」方式が**空集合を絶対に作らない**ことを実演しています。
自作の生成器は、必ず「作れない値」がないか確認してください。

## newtype ラッパーで生成戦略を切り替える

同じ型に対して複数の生成方法が欲しいときは、`newtype` でラップします。
QuickCheck 標準の Modifier（`Positive`, `NonEmptyList` など）もこの仕組みです。

```haskell
newtype AsciiWord = AsciiWord String
newtype NastyString = NastyString String   -- 意地悪な入力ばかり
newtype Boundary = Boundary Int            -- 境界値だけ
```

`newtype` は実行時コストがゼロです。いくらでも作って構いません。

## 関数を生成する：`Fun`

「どんな関数 `f` に対しても成り立つ」性質を書きたいとき。

```haskell
prop_mapFusion :: Fun Int Int -> Fun Int Int -> [Int] -> Property
prop_mapFusion (Fn f) (Fn g) xs = map f (map g xs) === map (f . g) xs
```

反例には `{0 -> False, _ -> True}` のような**関数の表**が表示されます。
（生成しただけの `Fun` を `print` すると `<fun>` としか出ません。
表が見えるのは縮小されたあと、つまり反例として表示されるときだけです）

自作の型で使うには `CoArbitrary` と `Function` が必要です。

```haskell
data Color = Red | Green | Blue deriving (Show, Eq, Enum, Bounded, Generic)
instance CoArbitrary Color                       -- Generic から自動導出
instance Function Color where
  function = functionMap fromEnum toEnum
```

## 型クラス則を検査する

自作インスタンスを書いたら、法則を必ず確認してください。

| クラス | 法則 |
|---|---|
| `Eq` | 反射律 / 対称律 / 推移律 |
| `Ord` | 反射律 / 反対称律 / 推移律 / 全域性 / `Eq` との整合 |
| `Semigroup` | 結合律 |
| `Monoid` | 左単位元 / 右単位元 |
| `Functor` | `fmap id == id` / `fmap (f.g) == fmap f . fmap g` |
| `Applicative` | 単位元律 / 合成律 / 準同型律 / 交換律 |
| `Monad` | 左単位元 / 右単位元 / 結合律 |

**1つだけ確かめても足りません。**
Example 43 では、「2つ目の要素を捨てる」Functor が
合成則だけを満たし、恒等則を破る様子を実演しています。

## `forAll` と `Arbitrary` の使い分け

| 使う場面 | どちら |
|---|---|
| その型の「標準的な値」が1つに決まる | `Arbitrary` インスタンス |
| 多くのテストで同じ生成方法を使う | `Arbitrary` インスタンス |
| テストごとに違う生成方法が要る | `forAll` |
| 他人のライブラリの型（orphan 回避） | `forAll` または `newtype` |
| 標準の分布では特定の分岐に届かない | `forAll` で専用生成器 |

実務のパターンは「型には無難な `Arbitrary` を書き、狙いたいテストでは `forAll` で上書き」です。

`forAll` は**縮小しません**。縮小が欲しいときは `forAllShrink` を使ってください。

| API | 特徴 |
|---|---|
| `forAllShrink gen shr f` | 基本これ |
| `forAll gen f` | 縮小不要のとき |
| `forAllBlind gen f` | `Show` がない型（関数など） |
| `forAllShow gen render f` | 表示を自分で制御したいとき |

## Example 一覧

| # | 内容 |
|---|---|
| [31](../examples/Example31.hs) | 自作型に `Arbitrary` を書く |
| [32](../examples/Example32.hs) | レコード型と列挙型。`verbose` との名前衝突に注意 |
| [33](../examples/Example33.hs) | 再帰型。素朴に書くと壊れる |
| [34](../examples/Example34.hs) | `sized` の書き方を身につける（式・ネスト・相互再帰） |
| [35](../examples/Example35.hs) | 不変条件を持つ型の3つの生成方法 |
| [36](../examples/Example36.hs) | `newtype` ラッパーで戦略を切り替える |
| [37](../examples/Example37.hs) | **実例**：JSON の生成器と往復テスト |
| [38](../examples/Example38.hs) | **実例**：日付。うるう年・月末の狙い撃ち生成器 |
| [39](../examples/Example39.hs) | 生成器を部品化して使い回す |
| [40](../examples/Example40.hs) | 無効な入力も生成する（negative testing） |
| [41](../examples/Example41.hs) | 関数を生成する（`Fun` / `applyFun`） |
| [42](../examples/Example42.hs) | `CoArbitrary` と `Function` |
| [43](../examples/Example43.hs) | 型クラス則を検査する |
| [44](../examples/Example44.hs) | `forAll` / `forAllShrink` / `forAllBlind` / `forAllShow` |
| [45](../examples/Example45.hs) | `Arbitrary` か `forAll` かの判断基準 |
| [46](../examples/Example46.hs) | **総合演習**：在庫管理の型を丸ごとテストする |

## 次へ

→ [第5章 縮小 (shrinking)](./05-shrinking.md)
