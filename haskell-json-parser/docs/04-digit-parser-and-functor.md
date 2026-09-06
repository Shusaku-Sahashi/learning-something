# 04. 数字パーサと Functor

対応する実装ファイル: `src/Exercise/Part1/Parser.hs`(セクション `docs/04-...`)

## digit1: 素朴な実装

1桁の数字を読み取って `Int` に変換するパーサを書きます。

```haskell
digit1 :: Parser String Int
```

使うのは `satisfy isDigit`(`Char` を1文字読み取る)と、`Data.Char.digitToInt`
(数字の `Char` を `Int` に変換する。例: `digitToInt '7' == 7`)です。

`satisfy isDigit :: Parser String Char` を実行すると `Maybe (String, Char)` が
返ってきます。これを `Maybe (String, Int)` に変換したい ―― つまり、
`Just (rest, c)` の `c` の部分だけを `digitToInt` で変換したいわけです。

```haskell
digit1 :: Parser String Int
digit1 = Parser $ \i -> case runParser (satisfy isDigit) i of
  Nothing      -> Nothing
  Just (i', o) -> Just (i', digitToInt o)
```

これを `src/Exercise/Part1/Parser.hs` に実装してください。動くには動きますが、
どこか冗長です。「`Maybe` の中身の、タプルの2番目の要素だけを変換する」という
処理を、毎回手でパターンマッチして書くのは面倒です。

## この「中身だけ変換する」操作、見覚えがありませんか

`Maybe` の中身を変換する操作には名前が付いています。`fmap` です。

```haskell
fmap :: (a -> b) -> Maybe a -> Maybe b
fmap f Nothing  = Nothing
fmap f (Just x) = Just (f x)
```

さらに、タプルの2番目の要素を変換する操作にも `fmap` が使えます(`(,) i` も
`Functor` のインスタンスで、`fmap` は2番目の要素だけに作用します)。

```haskell
fmap :: (a -> b) -> (i, a) -> (i, b)
fmap f (i, x) = (i, f x)
```

<details>
<summary>なぜ2番目の要素にしか作用しないのか(1番目にも適用したい場合は?)</summary>

`Functor` の定義を思い出してください。

```haskell
class Functor f where
  fmap :: (a -> b) -> f a -> f b
```

`f` は「型引数を1つ受け取れば具体的な型になる」というカインド(`Type -> Type`)を
持つ必要があります。タプルの型構築子 `(,)` は `Type -> Type -> Type` という
2引数のカインドなので、`Functor` のインスタンスにするには**どちらか一方の
型引数を固定して `Type -> Type` にする**必要があります。

```haskell
(,) i        -- i を固定 → 残り(2番目)が可変 → Functor にできる
```

Haskellの型適用は左から右に部分適用する形しかできないので、「2番目を固定して
1番目を可変にする」という書き方は言語機能として存在しません。だから普通の
`Functor` は**タプルの最後の型引数にしか作用できない**という制約があります
(3要素タプルなら3番目、4要素タプルなら4番目、というように「最後の要素」が
対象になります)。

1番目の要素(や、両方を別々の関数で)変換したい場合は、`Functor` ではなく
`Data.Bifunctor` を使います。

```haskell
class Bifunctor p where
  bimap  :: (a -> b) -> (c -> d) -> p a c -> p b d
  first  :: (a -> b) -> p a c -> p b c   -- 1番目だけ
  second :: (b -> c) -> p a b -> p a c   -- 2番目だけ (fmap と同じ)
```

実際に動かして確認しました。

```haskell
ghci> import Data.Bifunctor (first, second, bimap)
ghci> first (+1) (10, 5)
(11,5)      -- 1番目の 10 だけに +1 が適用される
ghci> second (+1) (10, 5)
(10,6)      -- 2番目の 5 だけに +1 が適用される (fmap と全く同じ結果)
ghci> bimap (+1) show (10, 5)
(11,"5")    -- 1番目に (+1)、2番目に show を、それぞれ別の関数で適用
```

ちなみに `Either` もタプルと同様に `Bifunctor` のインスタンスがあり(`first` が
`Left` 側、`second` が `Right` 側に作用)、`Functor` のインスタンスとしては
`Right` 側にしか `fmap` できません。これも同じ「最後の型引数にしか作用できない」
というルールの表れです。

</details>

つまり `digit1` でやっていた「`Maybe` の中の、タプルの2番目」という**2段階**の
変換は、`fmap` を**2回重ねる**だけで書けます。

```haskell
digit2 :: Parser String Int
digit2 = Parser $ \i -> case runParser (satisfy isDigit) i of
  Nothing      -> Nothing
  Just (i', o) -> Just . fmap digitToInt $ (i', o)
```

さらに `case` 式そのものも `Maybe` の `fmap` に置き換えられます。

> [!NOTE]
> <details>
> <summary>digit2 の case 式が、なぜ丸ごと fmap に置き換えられるのか</summary>
>
> `Maybe` の `fmap` の定義をもう一度見てください。
>
> ```haskell
> fmap :: (a -> b) -> Maybe a -> Maybe b
> fmap g Nothing  = Nothing
> fmap g (Just x) = Just (g x)
> ```
>
> これは言い換えると、「`Nothing -> Nothing`、`Just x -> Just (g x)` という
> `case` 式を書く代わりに `fmap g` と書ける」ということです。つまり
>
> ```haskell
> case maybeValue of
>   Nothing -> Nothing
>   Just x  -> Just (g x)
> ```
>
> という形の `case` 式を見かけたら、それは常に `fmap g maybeValue` **そのもの**
> です(定義そのままなので、書き換えではなく単なる別表記)。
>
> これを `digit2` の `case` 式に当てはめてみます。
>
> ```haskell
> case runParser (satisfy isDigit) i of
>   Nothing      -> Nothing
>   Just (i', o) -> Just . fmap digitToInt $ (i', o)
> ```
>
> - `maybeValue` に当たる部分 ＝ `runParser (satisfy isDigit) i`
> - `Just x -> Just (g x)` の `x` に当たる部分 ＝ `(i', o)` (パターンマッチで
>   分解されていますが、`Just x` の `x` が `(i', o)` という2要素タプルだ、と
>   読み替えるだけです)
> - `g x` に当たる部分 ＝ `fmap digitToInt $ (i', o)`、つまり `g = fmap digitToInt`
>   (タプルに対する `fmap`)
>
> これで「`maybeValue` は何か」「`g` は何か」の2つが分かったので、そのまま
> `fmap g maybeValue` の形に書き直せます。
>
> ```haskell
> fmap (fmap digitToInt) (runParser (satisfy isDigit) i)
> ```
>
> 外側の `fmap`(第1引数)が `Maybe` に対する `fmap`、その第1引数として渡している
> `fmap digitToInt` がタプルに対する `fmap` です。`case` 式が消えて、代わりに
> `fmap` が2重に(入れ子で)使われている点に注目してください。
>
> 最後に、`\i -> fmap (fmap digitToInt) (runParser (satisfy isDigit) i)` を
> `.`(関数合成)を使った書き方に直すと `digit3` の右辺になります(`$` は
> 「関数適用」を表す記号で、優先順位を下げて括弧を減らすためだけに使われています)。
>
> 実際に `digit2` と `digit3` を動かして、同じ結果になることを確認しました。
>
> ```haskell
> ghci> runParser digit2 "123"
> Just ("23",1)
> ghci> runParser digit3 "123"
> Just ("23",1)
> ghci> runParser digit2 "abc"
> Nothing
> ghci> runParser digit3 "abc"
> Nothing
> ```
>
> </details>

```haskell
digit3 :: Parser String Int
digit3 = Parser $ \i -> fmap (fmap digitToInt) . runParser (satisfy isDigit) $ i
```

`fmap (fmap digitToInt)` の外側の `fmap` は `Maybe` に対する `fmap`、
内側の `fmap` はタプルに対する `fmap` です。型で辿ると:

```
runParser (satisfy isDigit) i          :: Maybe (String, Char)
fmap digitToInt                        :: (String, Char) -> (String, Int)
fmap (fmap digitToInt)                 :: Maybe (String, Char) -> Maybe (String, Int)
```

## Parser 自体を Functor にする

`digit3` の右辺 `\i -> fmap (fmap digitToInt) . runParser (satisfy isDigit) $ i` を
よく見ると、これは「`i` によらない、`satisfy isDigit` というパーサを受け取って
別のパーサを返す」処理になっています。つまり `Parser` 自体に対して
「中身の結果だけを変換する」という `fmap` を定義できるはずです。

```haskell
instance Functor (Parser i) where
  fmap f parser = Parser $ ???
```

`parser :: Parser i o` を実行すると `Maybe (i, o)` が返ってきます。この
`Maybe (i, o)` の中身(タプルの2番目の要素)に `f` を適用したいわけです。
`digit3` で使ったのと同じ「`fmap` を2回重ねる」パターンがそのまま使えます。

`src/Exercise/Part1/Parser.hs` の `instance Functor (Parser i)` を実装してください。
型注釈は付いていませんが、`fmap :: (a -> b) -> Parser i a -> Parser i b` です。

実装できたら、`digit` を `<$>` を使って書き直します。`<$>` は `fmap` の中置演算子
(記号)版で、`f <$> x` は `fmap f x` と全く同じ意味です。パーサコンビネータの
コードでは `fmap` よりも `<$>` の形で書かれることが圧倒的に多いので、
慣れておいてください。

```haskell
digit :: Parser String Int
digit = digitToInt <$> satisfy isDigit
```

これも `src/Exercise/Part1/Parser.hs` に実装してください(`Functor` インスタンスさえ
できていれば1行で書けます)。

## Functor とは結局何なのか

`Functor` は「箱の中身だけを、箱の形を保ったまま変換する」ための型クラスです。
`Maybe`、リスト `[]`、タプルの2番目、そして今回の `Parser` ―― どれも
「何らかの文脈(失敗するかもしれない、複数の値がある、パースの残りの入力を
持ち回る)の中に値が入っている」形をしていて、その中身だけを変換したいという
場面は非常によく出てきます。だからこそ `Functor` は Haskell で最初に習う
基本的な型クラスの1つになっています。

```haskell
class Functor f where
  fmap :: (a -> b) -> f a -> f b
```

`f` の部分に `Maybe`、`[]`、`Parser i` などが入ります。今回 `Parser i` に対して
自分でこの `fmap` を実装したことで、「中身がどんな型でも、`f <$> parser` と書けば
パース結果を変換できる」という道具を手に入れたことになります。

## 動作確認

```
ghci> import Exercise.Part1.Parser
ghci> runParser digit "123"
Just ("23",1)
ghci> runParser digit "abc"
Nothing
```

## 次へ

[05. 文字列パーサと Applicative](05-string-parser-and-applicative.md) に進んでください。
