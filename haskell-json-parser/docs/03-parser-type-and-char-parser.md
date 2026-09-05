# 03. Parser 型と文字パーサ

対応する実装ファイル: `src/Exercise/Part1/Parser.hs`(セクション `docs/03-...`)

## パーサを「型」として定義する

パーサとは何かを、型で表現するところから始めます。パーサは「入力を受け取り、
できるところまで読み進めて、(残りの入力, 読み取った結果) を返す。読めなければ
失敗する」ものでした。これをそのまま関数の型にすると:

```haskell
i -> Maybe (i, o)
```

`i` が入力の型(今回は基本的に `String`)、`o` が読み取った結果の型です。
成功したら `Just (残りの入力, 結果)`、失敗したら `Nothing` を返します。

この関数を `newtype` でラップして名前を付けます(すでに `src/Exercise/Part1/Parser.hs`
に書かれています)。

```haskell
newtype Parser i o =
  Parser { runParser :: i -> Maybe (i, o) }
```

`newtype` は「1つのフィールドを持つ `data`」とほぼ同じですが、実行時のオーバーヘッドが
ないという特徴があります。`Parser` は「パーサの値」を表す型、
`runParser :: Parser i o -> i -> Maybe (i, o)` は「パーサに実際に入力を渡して実行する」
関数です。この「型を作って、実行する関数を分ける」パターンは、これから何度も
出てきます。

## char1: 1文字だけを見るパーサ

最初のパーサを書きます。「与えられた1文字と、入力の先頭が一致するかどうか」を
チェックするパーサです。

```haskell
char1 :: Char -> Parser String Char
```

### 実装のヒント

- `Parser` の中身は関数なので、`Parser $ \i -> ...` のような形になります。
- 入力 `i :: String` の**先頭1文字**を見て、それが引数の文字 `c` と一致するかで
  分岐します。`String` は `[Char]` なので、`(x:xs)` というパターンで
  「先頭の文字 `x` と残り `xs`」に分解できます。
- 入力が空文字列 `""` だったり、先頭文字が `c` と違ったりしたら `Nothing`。
- 一致したら `Just (残りの入力, 消費した文字)` を返します。

このファイルでは `{-# LANGUAGE LambdaCase #-}` 拡張が有効になっています。
`\case` は `\i -> case i of` の省略記法です。例えば:

```haskell
f = \case
  (x:xs) | x == 'a' -> ...
  _                 -> ...
```

は

```haskell
f = \i -> case i of
  (x:xs) | x == 'a' -> ...
  _                 -> ...
```

と同じ意味です(引数を明示的に書かなくてよくなる)。どちらの書き方でも構いません。

`src/Exercise/Part1/Parser.hs` の `char1` を実装してください。

## satisfy: 述語を受け取る汎用版

`char1` は「特定の1文字と一致するか」しか判定できません。もっと汎用的に、
「先頭の要素が何らかの条件(述語関数)を満たすか」を判定できるパーサを書きます。

```haskell
satisfy :: (a -> Bool) -> Parser [a] a
```

`String` ではなく `[a]` を受け取る型になっている点に注目してください。文字列に
限らず、任意のリストに対して使える汎用的なパーサになっています。

やることは `char1` とほぼ同じで、「`x == c`」の部分が「`predicate x`」になるだけです。
実装したら、`char1` は実質 `satisfy` の特殊ケースだと気づけるはずです。実際、
そのことを使って `char` を書き直します。

```haskell
char :: Char -> Parser String Char
char c = satisfy (== c)
```

これは既に実装されています(`(== c)` は「`c` と等しいかを判定するセクション」)。
`satisfy` さえ実装できれば `char` はタダで手に入ります。これが「小さい部品を
組み合わせて大きい部品を作る」というパーサコンビネータの最初の実例です。

## 動作確認

`satisfy` と `char1` を実装したら、GHCi で試してみましょう。

```bash
cabal repl lib:haskell-json-parser
```

```
ghci> import Exercise.Part1.Parser
ghci> runParser (char1 'a') "abhinav"
Just ("bhinav",'a')
ghci> runParser (char1 'a') "sarkar"
Nothing
ghci> runParser (char 'x') "xyz"
Just ("yz",'x')
```

## 次へ

[04. 数字パーサと Functor](04-digit-parser-and-functor.md) に進んでください。
