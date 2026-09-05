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

つまり `digit1` でやっていた「`Maybe` の中の、タプルの2番目」という**2段階**の
変換は、`fmap` を**2回重ねる**だけで書けます。

```haskell
digit2 :: Parser String Int
digit2 = Parser $ \i -> case runParser (satisfy isDigit) i of
  Nothing      -> Nothing
  Just (i', o) -> Just . fmap digitToInt $ (i', o)
```

さらに `case` 式そのものも `Maybe` の `fmap` に置き換えられます。

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
