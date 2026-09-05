# Appendix. QuickCheck と Property-based Testing 入門

このAppendixは、本編のどこかで一度読めば十分な独立した解説です。
本編(`docs/02-json-data-type.md`)からリンクされています。ここを読み終える頃には、
このプロジェクトの `Json.Gen` や `prop_genParseJString` が何をしているか理解でき、
かつ**自分で新しいプロパティベーステストを一から書ける**ようになることを
目指します。

## 1. おさらい: Property-based Testing とは

普通の(Example-based な)テストは、特定の入力に対する特定の出力を確認します。

```haskell
reverse [1,2,3] == [3,2,1]  -- 1つの具体例
```

**Property-based Testing(PBT)** は、「どんな入力に対しても成り立つべき性質」を
書き、ランダムな入力を大量に自動生成してその性質を検証します。

```haskell
-- どんな xs :: [Int] に対しても、2回 reverse したら元に戻る
prop_reverseReverse :: [Int] -> Bool
prop_reverseReverse xs = reverse (reverse xs) == xs
```

ライブラリ([QuickCheck](https://hackage.haskell.org/package/QuickCheck))が
`xs` の値をランダムに(既定では100個)生成し、それぞれについて
`prop_reverseReverse xs` が `True` になるか確認します。1つでも `False` に
なったら失敗を報告します。

このアプローチの利点:

- 「思いつかなかったエッジケース」を人間の代わりに機械が見つけてくれる。
- テストコードが「実装のふるまいそのもの」を表現するので、テストを読むと
  仕様が分かる。
- 失敗したときに、QuickCheck が入力を自動的に**単純化(shrink)** してから
  見せてくれるので、デバッグしやすい(後述)。

## 2. Gen: ランダムな値の生成器

QuickCheck で最初に理解すべき型が `Gen a` です。「型 `a` の値をランダムに
生成する方法」を表します。`Gen a` の値そのものはまだ何のランダム値も
持っておらず、「どうやって生成するか」というレシピです。

### 2.1 組み込みのコンビネータ

| 関数 | 型 | 意味 |
|---|---|---|
| `choose` | `(Int, Int) -> Gen Int` | 範囲内の値を一様分布で選ぶ(`Int` に限らず `Random` クラスのインスタンス全般で使える) |
| `elements` | `[a] -> Gen a` | リストから1つを選ぶ |
| `oneof` | `[Gen a] -> Gen a` | ジェネレータのリストから1つを選び、それを実行する |
| `frequency` | `[(Int, Gen a)] -> Gen a` | `oneof` の重み付き版。数字が大きいほど選ばれやすい |
| `listOf` | `Gen a -> Gen [a]` | 0個以上のリストを生成(個数もランダム) |
| `listOf1` | `Gen a -> Gen [a]` | 1個以上のリストを生成 |
| `vectorOf` | `Int -> Gen a -> Gen [a]` | ちょうど指定した個数のリストを生成 |
| `suchThat` | `Gen a -> (a -> Bool) -> Gen a` | 条件を満たすまで生成をやり直す |
| `sized` | `(Int -> Gen a) -> Gen a` | 「サイズ」パラメータを受け取れるジェネレータにする(後述) |
| `scale` | `(Int -> Int) -> Gen a -> Gen a` | サイズパラメータを変換してから使う |

実際に触ってみましょう。GHCi で:

```
ghci> import Test.QuickCheck
ghci> generate (choose (1, 6))       -- サイコロ
4
ghci> generate (elements "abcde")
'c'
ghci> generate (vectorOf 5 (choose (0, 9)))
[3,7,1,9,0]
ghci> generate (listOf (elements "ab"))
"abaabbba"
```

`generate :: Gen a -> IO a` は「実際に1つ値を生成して見せる」ためのデバッグ用
関数です。プロパティの中では使いません(QuickCheck が内部で自動的に何度も
呼び出してくれます)。

### 2.2 Gen も Functor / Applicative / Monad

`Gen` も本編で学んだ型クラスのインスタンスです。「小さいジェネレータを
組み合わせて大きいジェネレータを作る」ときに、`<$>`/`<*>`/`do` がそのまま
使えます。

```haskell
data Point = Point { x :: Int, y :: Int } deriving Show

pointGen :: Gen Point
pointGen = Point <$> choose (-10, 10) <*> choose (-10, 10)

-- do 構文でも書ける(こちらのほうが読みやすいことも多い)
pointGen2 :: Gen Point
pointGen2 = do
  x' <- choose (-10, 10)
  y' <- choose (-10, 10)
  pure (Point x' y')
```

「パーサ」を組み立てたときとまったく同じ発想であることに気づいてください。
`Parser` も `Gen` も、どちらも「文脈(パースの残り入力/ランダム性)を
持ち回りながら値を組み立てる」という同じ形をしています。

### 2.3 sized: 再帰的なデータ構造のジェネレータ

`JValue` のように「配列やオブジェクトが自分自身を含みうる」再帰的な型を
生成しようとすると、素朴に書くと生成がいつまでも終わらなかったり、
巨大な値になってしまったりします。これを防ぐのが `sized` です。

```haskell
sized :: (Int -> Gen a) -> Gen a
```

QuickCheck はテストを実行するたびに「サイズ」という `Int` の目安値
(だんだん大きくしていく)を持っており、`sized f` は現在のサイズを `f` に
渡します。再帰する側で `scale (`div` 2)` のようにサイズを小さくしていくことで、
再帰が有限回で終わることを保証します。実際に `src/Json/Gen.hs` の
`jArrayGen`/`jObjectGen`/`jValueGen` がこのパターンを使っています。

```haskell
jArrayGen :: Int -> Gen JValue
jArrayGen = fmap JArray . scale (`div` 2) . listOf . jValueGen . (`div` 2)
```

「配列の中身を生成するときは、サイズを半分にしてから `jValueGen` を呼ぶ」
ことで、ネストが深くなるほど生成される値が小さくなり、いつか必ず
スカラー値(null/bool/string/number)だけになって再帰が止まります。

## 3. Arbitrary: 型ごとの「既定の」生成方法

```haskell
class Arbitrary a where
  arbitrary :: Gen a
  shrink    :: a -> [a]
```

`Int`, `Bool`, `String`, `[a]` など、標準的な型にはあらかじめ
`Arbitrary` インスタンスが用意されています。`arbitrary :: Gen Int` のように
書くだけでランダムな `Int` が手に入ります。

このプロジェクトでは `JValue` にも `Arbitrary` インスタンスを用意しています
(`src/Json/Gen.hs`)。

```haskell
instance Arbitrary JValue where
  arbitrary = sized jValueGen
  shrink    = genericShrink
```

`genericShrink` は `GHC.Generics` の `Generic` インスタンス(`JValue` の
`deriving (..., Generic)` を思い出してください)を使って、
「コンストラクタの引数を1つずつ、より単純な値に置き換えてみる」という
縮小処理を自動的に導出してくれる QuickCheck の関数です。自分でゼロから
`shrink` を書く必要がなくなります。

## 4. Property: 性質の書き方

### 4.1 一番シンプルな形

`Bool` を返す普通の関数がそのままプロパティになります。

```haskell
prop_reverseReverse :: [Int] -> Bool
prop_reverseReverse xs = reverse (reverse xs) == xs
```

`quickCheck prop_reverseReverse` を実行すると、QuickCheck は
`[Int]` の `Arbitrary` インスタンスを使って `xs` をランダムに100個生成し、
それぞれについて関数を評価します。

### 4.2 Property 型と forAll / forAllShrink

型シグネチャの都合(このプロジェクトのように `Gen` の中で `IO` 風の処理を
挟みたい場合など)で `Bool` ではなく `Property` を返したいことがあります。

```haskell
forAll      :: (Show a, Testable prop) => Gen a -> (a -> prop) -> Property
forAllShrink :: (Show a, Testable prop)
             => Gen a -> (a -> [a]) -> (a -> prop) -> Property
```

`forAll gen f` は「`gen` で値を生成し、それを `f` に渡して得られる
プロパティを検証する」という意味です。`Arbitrary` インスタンスに頼らず、
**その場で指定したジェネレータ**を使いたいときに使います。
`forAllShrink` はそれに加えて「失敗したときにどう縮小するか」も指定できる版です。

このプロジェクトの `prop_genParseJString` を見てみましょう
(`src/Exercise/Part1/Parser.hs` / `solutions/Solutions/Part1.hs`)。

```haskell
prop_genParseJString :: Property
prop_genParseJString =
  forAllShrink jStringGen shrink $ \js ->
    case runParser jString (show js) of
      Nothing     -> False
      Just (_, o) -> o == js
```

- `jStringGen :: Gen JValue` ―― `JString` だけを生成する専用ジェネレータ
  (`arbitrary` のように任意の `JValue` を生成すると配列やオブジェクトも
  混ざってしまうので、あえて専用のものを使っています)。
- `shrink` ―― `JValue` の `Arbitrary` インスタンスにある `shrink`
  (`genericShrink`)をそのまま使う。
- 生成された `js` を `show`(`Json.Value` の `Show` インスタンス、
  JSON テキストへの変換)し、それを自分たちの `jString` パーサでパースし、
  元の `js` と一致するか確認する。

### 4.3 counterexample: 失敗時の情報を追加する

```haskell
counterexample :: Testable prop => String -> prop -> Property
```

`counterexample msg prop` は「`prop` が失敗したときに `msg` も一緒に
表示する」というものです。`prop_genParseJArray` で使われています。

```haskell
prop_genParseJArray :: Property
prop_genParseJArray =
  forAllShrink (sized jArrayGen) shrink $ \ja -> do
    jas <- dropWhile isSpace <$> stringify ja
    return . counterexample (show jas) $ case runParser jArray jas of
      Nothing     -> False
      Just (_, o) -> o == ja
```

この関数の型に注目すると、`do` ブロック全体が `Gen Property` になっています
(`stringify ja :: Gen String` なので)。「`JValue` を生成する」だけでなく
「それを JSON テキスト化する」処理まで`Gen` モナドの中に含めているので、
`return`(`Gen` にとっての `pure`)で包んで `Property` に変換しています。
失敗したときに、生成された `JValue` そのものではなく、実際にパーサへ
渡した JSON テキスト `jas` が表示されるようにしているのがこの
`counterexample` の役割です。

### 4.4 ==>: 前提条件を絞り込む(このプロジェクトでは未使用)

「特定の条件を満たす入力だけ」に性質を限定したいときは `==>` を使います。

```haskell
prop_divMod :: Int -> Int -> Property
prop_divMod x y = y /= 0 ==> (x `div` y) * y + (x `mod` y) == x
```

条件を満たさない入力は捨てられ、カウントされません(あまり多く捨てられすぎると
QuickCheck が警告を出します)。今回の JSON パーサでは、ジェネレータ自体が
最初から「妥当な JSON 値」だけを作るので `==>` は使っていませんが、
一般にはよく使われるので覚えておいてください。

## 5. quickCheck の実行方法いろいろ

| 関数 | 挙動 |
|---|---|
| `quickCheck :: Testable prop => prop -> IO ()` | 実行して結果を標準出力に表示するだけ |
| `quickCheckResult :: Testable prop => prop -> IO Result` | 結果を `Result` 値として受け取れる |
| `verboseCheck :: Testable prop => prop -> IO ()` | 生成された値を毎回表示しながら実行(デバッグ用) |

`test/Part1Spec.hs` などこのプロジェクトのテストは `quickCheckResult` を
使い、`isSuccess :: Result -> Bool` で成否を判定して、1つでも失敗すれば
`exitFailure` するようになっています。これは `cabal test` が
「テストスイートが失敗したら 0 以外の終了コードを返す」ことを期待するためです
(`quickCheck` だけだと常に正常終了してしまい、CI で失敗を検知できません)。

## 6. Shrinking: 失敗例を単純化する仕組み

QuickCheck はテストが失敗すると、その入力を `shrink` 関数を使って
「もっと単純な、それでも失敗する入力」に段階的に置き換えていきます。
たとえば `[5, -3, 12, 0, 8]` で失敗したなら、`[]`、`[0]`、`[5]`、
`[5, -3]` … のように試していき、最終的に「これ以上単純にできない、
最小の失敗例」を表示します。これにより、巨大でランダムな入力ではなく、
人間がデバッグしやすい最小限の反例を見ることができます。

`shrink :: a -> [a]` は「その値を少しだけ単純にしたバリエーションの候補
リスト」を返す関数です。リストなら「要素を1つ減らす」「各要素自体を
shrink する」など、標準の `Arbitrary` インスタンスがすでに妥当な実装を
持っています。自分で定義したデータ型には、`Generic` を `derive` した上で
`genericShrink` を使うのがもっとも簡単な方法です(このプロジェクトの
`JValue` がまさにその例です)。

## 7. 実践: 何もないところから PBT を書いてみる

ここまでの内容を使って、このプロジェクトとは無関係な例で練習してみましょう。
「挿入ソート `insertSorted` は、ソート済みリストに対して使うと、
結果もソート済みのままである」という性質を検証します。

```haskell
import Test.QuickCheck
import Data.List (sort, insert)

-- テスト対象(わざと単純な実装)
insertSorted :: Ord a => a -> [a] -> [a]
insertSorted = insert

isSorted :: Ord a => [a] -> Bool
isSorted xs = and (zipWith (<=) xs (drop 1 xs))

prop_insertKeepsSorted :: Int -> [Int] -> Property
prop_insertKeepsSorted x xs =
  forAll (pure (sort xs)) $ \sortedXs ->
    isSorted (insertSorted x sortedXs)
```

GHCi で試してみてください。

```
ghci> import Test.QuickCheck
ghci> quickCheck prop_insertKeepsSorted
+++ OK, passed 100 tests.
```

わざと壊れた実装(たとえば `insertSorted x xs = x : xs`、先頭に付け足すだけ)
に差し替えて実行し、QuickCheck がどんな反例を見つけて、どう縮小するかを
実際に観察してみることを強くお勧めします。これが体感できれば、
PBT を自分のコードに応用する準備は整っています。

## 8. 腕試し: Json.Gen を自分で書いてみる

対応する実装ファイル: `src/Exercise/Appendix/Gen.hs`

ここまでの内容を使って、今度は**このプロジェクトの `Json.Gen` と同じもの**を
何も見ずに自分の手で実装してみましょう。**Part1 か Part2 のどちらかを
先に完成させてから**取り組んでください(自分で書いたジェネレータを、
自分で書いたパーサでテストする、という腕試しだからです)。

`src/Exercise/Appendix/Gen.hs` に、以下の関数の型シグネチャだけが用意されています。

```haskell
jNullGen          :: Gen JValue
jBoolGen          :: Gen JValue
jNumberGen        :: Gen JValue
jsonStringGen     :: Gen String
jStringGen        :: Gen JValue
jArrayGen         :: Int -> Gen JValue
jObjectGen        :: Int -> Gen JValue
jValueGen         :: Int -> Gen JValue
jsonWhitespaceGen :: Gen String
stringify         :: JValue -> Gen String
```

ヒント:

- `jNullGen`/`jBoolGen`/`jNumberGen` はスカラー値のジェネレータです。
  2節「Gen: ランダムな値の生成器」の `<$>`/`<*>`、`arbitrary`
  (`Bool`/`Integer`/`Int` にはすでに `Arbitrary` インスタンスがあります)、
  `listOf`/`choose` を使います。
- `jsonStringGen` は「素の Unicode 文字1つ」か「`\u` + 16進数4桁の
  エスケープ」のどちらかを繰り返し生成し、連結したものです。`oneof`、
  `vectorOf`、`arbitraryUnicodeChar`(QuickCheck が提供する既製の
  ジェネレータ)を使います。
- `jArrayGen`/`jObjectGen`/`jValueGen` は相互再帰します。2.3節で説明した
  `sized`/`scale` のパターン(再帰する側でサイズを半分にする)を必ず
  使ってください。使わないと生成が終わらなくなります(GHCi がフリーズして
  見えたら `Ctrl+C` で中断し、`scale` を見直してください)。
- `jValueGen n` は、`n` が小さいときはスカラー値に、大きいときは複合値に
  偏るように `frequency` で重み付けします。
- `stringify` は `JValue` を JSON テキストに変換しつつ、値の前後・配列や
  オブジェクトの要素の前後にランダムな空白(`jsonWhitespaceGen`)を
  挟み込みます。スカラー値は `show`(`Json.Value` の `Show` インスタンス、
  02 で実装したもの)にそのまま任せられます。配列・オブジェクトは
  `mapM`(要素ごとに `Gen String` を作り、まとめて `Gen [String]` にする)
  を使って再帰的に組み立てます。

`instance Arbitrary JValue` は再定義しません(モジュール冒頭のコメントに
理由が書いてあります ―― `Json.Gen` がすでに定義しているものが、
`Exercise.Part1.Parser` 経由でテスト実行時に使われます)。

実装できたら検証します。

```bash
cabal test appendix-gen
```

これは、あなたが実装した `jValueGen`/`stringify` で JSON 値を生成し、
あなたが実装した `parseJSON`(Part1)でパースして、元の値に戻るかを
確認するプロパティです。`+++ OK, passed 100 tests.` が出れば、
ジェネレータもパーサも正しく噛み合っていることになります。

答え合わせをしたい・詰まった場合は `src/Json/Gen.hs`(このプロジェクト
本編で最初から使われている、同じ内容の「与えられたコード」)を見てください。

## 9. このプロジェクトのコードを読み直す

ここまで読んだら、`src/Json/Gen.hs` と `test/Part1Spec.hs` /
`test/Part2Spec.hs` をもう一度読み返してみてください。最初に読んだときより
「なぜこう書かれているか」がずっと具体的に見えるはずです。特に8節を
自力でやり切った後なら、1行1行が「なぜそう書く必要があったか」まで
含めて読めるようになっているはずです。

## 参考資料

- [QuickCheck の Hackage ドキュメント](https://hackage.haskell.org/package/QuickCheck)
- [Real World Haskell, Chapter 11: Testing and Quality Assurance](http://book.realworldhaskell.org/read/testing-and-quality-assurance.html)
- 原典: [John Hughes, "QuickCheck: A Lightweight Tool for Random Testing of Haskell Programs"](https://www.cse.chalmers.se/~rjmh/QuickCheck/manual.html)
