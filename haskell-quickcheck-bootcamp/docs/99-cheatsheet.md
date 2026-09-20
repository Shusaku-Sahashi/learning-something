# 📇 QuickCheck API 早見表

動作確認バージョン: **QuickCheck 2.14.3 / GHC 9.4.7**

## 実行

| API | 役割 |
|---|---|
| `quickCheck prop` | 100 回試す |
| `quickCheckWith args prop` | 設定を指定して試す |
| `quickCheckResult prop` | `Result` を返す |
| `quickCheckWithResult args prop` | 両方 |
| `verboseCheck prop` | 生成値を1件ずつ表示 |
| `verboseCheckWith args prop` | 同上（設定付き） |

## `Args`

| フィールド | 既定 | 意味 |
|---|---|---|
| `maxSuccess` | 100 | 何件通れば合格か |
| `maxSize` | 100 | 生成サイズの上限 |
| `maxDiscardRatio` | 10 | 捨てた入力の許容比率 |
| `maxShrinks` | `maxBound` | 縮小の最大試行回数 |
| `chatty` | `True` | 進捗を表示するか |
| `replay` | `Nothing` | `Just (QCGen, Int)` で乱数を固定 |

## `Result`

| フィールド | 意味 |
|---|---|
| `isSuccess r` | 成否（関数） |
| `numTests` | 実行したテスト数 |
| `numDiscarded` | 捨てた入力数 |
| `numShrinks` | 縮小の回数 |
| `failingTestCase` | 反例（`[String]`） |
| `reason` | 失敗理由 |
| `theException` | 例外（あれば） |
| `usedSeed` / `usedSize` | 再現に使う情報 |
| `labels` / `classes` / `tables` | 集計結果 |
| `output` | 表示されるはずだった文字列全体 |

## 比較・合成

| API | 役割 |
|---|---|
| `(===)` | 等価。失敗時に `a /= b` を表示 |
| `(=/=)` | 非等価 |
| `(.&&.)` / `(.\|\|.)` | かつ／または（短絡しない） |
| `conjoin` / `disjoin` | リスト版 |
| `counterexample s prop` | 反例に情報を足す |
| `(?)` | `counterexample` の中置版 |

## プロパティ修飾

| API | 役割 |
|---|---|
| `property x` | `Bool` などを `Property` に持ち上げる |
| `withMaxSuccess n prop` | テスト回数を変える |
| `once prop` | 1回だけ実行 |
| `again prop` | `once` を打ち消す |
| `mapSize f prop` | サイズを変換（**プロパティ全体を包むこと**） |
| `expectFailure prop` | 「失敗するはず」を表明 |
| `within µs prop` | タイムアウト |
| `noShrinking prop` | 縮小を無効化 |
| `verbose prop` | 生成値を表示 |
| `verboseShrinking prop` | 縮小の過程を表示 |
| `total x` | 完全に評価して例外が出ないこと（`NFData` が必要） |

## 前提条件

| API | 役割 |
|---|---|
| `(==>)` | 条件付きプロパティ |
| `discard` | この入力を捨てる（どんな型としても使える） |

## `forAll` 系

| API | 縮小 | 表示 |
|---|---|---|
| `forAll gen f` | ✗ | `Show` |
| `forAllShrink gen shr f` | ○ | `Show` |
| `forAllBlind gen f` | ✗ | しない |
| `forAllShrinkBlind gen shr f` | ○ | しない |
| `forAllShow gen render f` | ✗ | 自前 |
| `shrinking shr x f` | ○ | 外側は縮小されない |

## 生成器の部品

| API | 役割 |
|---|---|
| `arbitrary` | `Arbitrary` インスタンスの生成器 |
| `choose (lo, hi)` | 閉区間から一様に |
| `chooseInt (lo, hi)` | `Int` 専用 |
| `elements xs` | リストから一様に（空だとエラー） |
| `oneof gs` | 生成器から等確率で |
| `frequency [(w,g)]` | 重み付きで |
| `listOf g` / `listOf1 g` | リスト／空でないリスト |
| `vectorOf n g` | 長さちょうど n |
| `infiniteListOf g` | 無限リスト |
| `shuffle xs` | 並べ替え |
| `sublistOf xs` | 各要素を 50% で採用 |
| `growingElements xs` | サイズに応じて後ろも選ばれる |
| `suchThat g p` | 条件を満たすまで再生成（遅い） |
| `suchThatMaybe g p` | 有限回で諦めて `Nothing` |
| `suchThatMap g f` | 生成しつつ変換 |
| `arbitraryBoundedEnum` | `Enum` + `Bounded` から |
| `sized f` | サイズを使う |
| `getSize` | サイズを取り出す |
| `resize n g` | サイズを固定 |
| `scale f g` | サイズを変換 |
| `generate g` | 値を1つ取り出す（IO） |
| `sample g` / `sample' g` | 11 個表示／取得 |

## 縮小の部品

| API | 役割 |
|---|---|
| `shrink x` | `Arbitrary` の縮小 |
| `shrinkNothing` | 縮小しない |
| `shrinkIntegral` / `shrinkRealFrac` | 数値 |
| `shrinkList shr xs` | リスト（`const []` で「削るだけ」） |
| `shrinkMap to from` | 変換してから縮小 |
| `shrinkMapBy to from shr` | 縮小関数も指定 |
| `genericShrink` | `Generic` から自動導出 |

## Modifier

| Modifier | コンストラクタ | 意味 |
|---|---|---|
| `Positive a` | `Positive n` | > 0 |
| `NonNegative a` | `NonNegative n` | >= 0 |
| `Negative a` | `Negative n` | < 0 |
| `NonPositive a` | `NonPositive n` | <= 0 |
| `NonZero a` | `NonZero n` | /= 0 |
| `Small a` | `Small n` | 小さい値 |
| `Large a` | `Large n` | 大きい値も |
| `NonEmptyList a` | **`NonEmpty xs`** | 空でないリスト |
| `OrderedList a` | **`Ordered xs`** | 昇順 |
| `SortedList a` | **`Sorted xs`** | 昇順 |
| `InfiniteList a` | `InfiniteList xs _` | 無限リスト |
| `ASCIIString` | `ASCIIString s` | ASCII だけ |
| `PrintableString` | `PrintableString s` | 表示可能文字だけ |
| `UnicodeString` | `UnicodeString s` | Unicode 全域 |
| `Blind a` | `Blind x` | 表示しない |
| `Fixed a` | `Fixed x` | 縮小しない |
| `Shrink2 a` | `Shrink2 x` | 2段階縮小 |
| `Fun a b` | **`Fn f`** | 生成された関数 |

⚠️ 太字は型名とコンストラクタ名が違うもの。

## 関数の生成

| API | 役割 |
|---|---|
| `Fun a b` / `Fn f` | 表示できる関数 |
| `applyFun f` | 関数として適用 |
| `Fn2` / `Fn3` | 2引数・3引数のパターン |
| `CoArbitrary a` | `a` を関数の入力に使うため |
| `Function a` | `Fun a b` を表示・縮小するため |
| `functionMap to from` | 既存の `Function` に変換して実装 |
| `variant n` | 乱数の流れを分岐（`coarbitrary` の実装用） |

## 分布とカバレッジ

| API | 役割 |
|---|---|
| `collect x prop` | 値の分布 |
| `label s prop` | 常に記録（排他的カテゴリ） |
| `classify cond s prop` | 条件が真のときだけ記録 |
| `tabulate name [s] prop` | 名前付きの表 |
| `cover pct cond s prop` | ラベルの下限（警告のみ） |
| `coverTable name [(s,pct)] prop` | 表全体の下限 |
| `checkCoverage prop` | 下限を満たさなければ失敗 |

## IO と例外

| API | 役割 |
|---|---|
| `ioProperty io` | IO の結果をプロパティに |
| `monadicIO m` | 手続き的に書く |
| `run io` | `PropertyM` の中で IO を実行 |
| `assert b` | 条件を確かめる |
| `pre b` | 前提条件 |
| `monitor f` | `counterexample` などを足す |
| `pick gen` | 途中で値を生成（縮小されない） |
| `try action` | IO の例外を捕まえる（`Control.Exception`） |
| `try (evaluate e)` | 純粋な式の例外を捕まえる |

## 再現

```haskell
import Test.QuickCheck.Random (mkQCGen)

quickCheckWith stdArgs { replay = Just (mkQCGen 42, 0) } prop
```

```haskell
import Test.QuickCheck.Gen (unGen)

unGen gen (mkQCGen 2024) 30   -- 生成器を直接走らせる
```

## よくあるエラー

| メッセージ | 原因 |
|---|---|
| `No instance for (Show ...)` | プロパティの引数の型に `Show` がない。`deriving (Show)` を足す |
| `Ambiguous type variable` | 型注釈がない。`(xs :: [Int])` や `(arbitrary :: Gen [Cmd])` を足す |
| `Ambiguous occurrence 'total'` | `Test.QuickCheck.total` とレコードフィールドの衝突。名前を変える |
| `Ambiguous occurrence 'verbose'` | 同上 |
| `No instance for (Testable (IO ()))` | `IO ()` は `Testable` ではない。`ioProperty` を使う |
| `Gave up! Passed only N tests` | 前提条件が厳しすぎる。生成器を直す（第6章） |
| `Insufficient coverage` | `cover` のしきい値に届いていない（第7章） |
| テストが固まる | `shrink` の無限ループ（第5章）。`maxShrinks = 0` で切り分ける |
| 一瞬で通るがバグが出ない | 型が `()` に defaulting されている（第1章 Example 06） |

## ライブラリ間の対応

| QuickCheck | Hedgehog |
|---|---|
| `Arbitrary` + `shrink` | `Gen`（縮小は自動） |
| `forAll gen f` | `forAll gen` |
| `quickCheck prop` | `check prop` |
| `classify` | `classify` |
| `cover` | `cover` |
| `===` | `===` |
