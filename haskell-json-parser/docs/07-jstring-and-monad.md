# 07. Unicode サロゲートペアと Monad

対応する実装ファイル: `src/Exercise/Part1/Parser.hs`(セクション `docs/07-...`)

## jsonChar: 1つの JSON 文字をパースする

JSON 文字列の中身をパースする前に、「1文字」の定義を明確にします。JSON の文字列は
以下のいずれかの並びです。

- エスケープされた特殊文字: `\"`, `\\`, `\/`, `\b`, `\f`, `\n`, `\r`, `\t`
- `\u` に続く4桁の16進数によるコードポイント指定 (`\u3042` は `あ`)
- それ以外の、ダブルクォート・バックスラッシュ・制御文字を除く任意の文字

```haskell
jsonChar :: Parser String Char
```

これは今まで作った道具(`string`, `$>`, `<|>`, `<$>`)だけで書けます。

```haskell
jsonChar =   string "\\\"" $> '"'
         <|> string "\\\\" $> '\\'
         <|> string "\\/"  $> '/'
         <|> string "\\b"  $> '\b'
         <|> string "\\f"  $> '\f'
         <|> string "\\n"  $> '\n'
         <|> string "\\r"  $> '\r'
         <|> string "\\t"  $> '\t'
         <|> unicodeChar
         <|> satisfy (\c -> not (c == '\"' || c == '\\' || isControl c))
  where
    unicodeChar =
      chr . fromIntegral . digitsToNumber 16 0
        <$> (string "\\u" *> replicateM 4 hexDigit)
    hexDigit = digitToInt <$> satisfy isHexDigit
```

`src/Exercise/Part1/Parser.hs` に実装してください。新しく出てくる道具:

- `Control.Monad.replicateM :: Int -> Parser i a -> Parser i [a]`
  ―― 「同じパーサを `n` 回繰り返し実行して、結果をリストにまとめる」もの。
  `\u3042` の4桁の16進数を読むのに使います。
- `*> :: Applicative f => f a -> f b -> f b`
  ―― `<*>` の仲間で、「左側を実行するが結果は捨てて、右側の結果だけを返す」。
  `string "\\u" *> replicateM 4 hexDigit` は「`\u` を読み飛ばして、続く4桁を返す」。
- `Data.Char.isHexDigit` / `Data.Char.digitToInt` / `Data.Char.chr` /
  `Numeric` の逆にあたる、16進数の桁のリストから文字コードを組み立てる
  `digitsToNumber`(すでに実装済みです)。

`<|>` を8つも並べているのは、`Alternative` が「好きなだけ選択肢を並べられる」ことの
表れです。**順番が重要**であることに注意してください。最後の
`satisfy (\c -> ...)` が一番「何でも受け入れる」条件なので、最後に置かないと
他のエスケープ処理より先にマッチしてしまいます。

## jString: 見た目ほど簡単ではない

「文字列は文字のリストなのだから、`jsonChar` を繰り返し読めばいいのでは?」と
思うかもしれませんが、そう単純ではありません。理由は Unicode の
**サロゲートペア**です。

Unicode のコードポイントは最大 `U+10FFFF` まであります。しかし JSON の
`\uXXXX` 記法は4桁の16進数、つまり `U+0000`〜`U+FFFF` しか直接表現できません
(この範囲を **基本多言語面 (BMP)** と呼びます)。BMP の外にある文字
(絵文字や一部の漢字など)を表現するために、JSON(というより UTF-16)は
**サロゲートペア**という仕組みを使います。2つの特別なコードポイント
(High Surrogate: `U+D800`〜`U+DBFF`、Low Surrogate: `U+DC00`〜`U+DFFF`)を
組み合わせて、1つの文字を表現するのです。

つまり `jsonChar` を1回呼んで得られた文字が High Surrogate だったら、
**もう1回 `jsonChar` を呼んで** Low Surrogate を取得し、2つを合成する必要が
あります。「1回目の結果を見てから、2回目に何をするか決める」という、
**前の結果に依存した分岐**が必要になったわけです。

## これまでの道具では足りない

`Applicative` の `<*>` を思い出してください。`pf <*> po` は「`pf` と `po`
という**2つの独立したパーサ**を実行して結果を組み合わせる」ものでした。
`po` の中身は `pf` の**結果を見てから**決めることはできません
(`pf` と `po` は最初から両方とも決まった値です)。

しかし今回必要なのは「1文字読んで、**その結果を見てから**、次に何を読むかを
決める」という処理です。これは `Applicative` の表現力を超えています。

## Monad: 前の結果を使って次を決める

そこで `Monad` 型クラスの出番です。

```haskell
class Applicative m => Monad m where
  (>>=) :: m a -> (a -> m b) -> m b
```

`p >>= f` は「`p` を実行し、その結果 `x` を `f` に渡して `f x` というパーサを
作り、それを実行する」という意味です。`f :: a -> m b` の**戻り値の型に
`p` の結果を渡せる**ことがポイントです。これでようやく「前の結果を見てから
次のパーサを決める」ことができます。

`src/Exercise/Part1/Parser.hs` の `instance Monad (Parser i)` を実装して
ください。方針:

- `p >>= f` を実行するには、まず `p` を入力に対して実行する。
- 失敗したら全体も失敗。
- 成功したら、その結果 `o` を `f` に渡して `f o :: Parser i b` を作り、
  それを**残りの入力**に対して実行する。

## do 構文

`>>=` を直接使わなくても、`do` 構文を使えば「前の行の結果を次の行で使う」
処理を手続き型言語のように書けます。次の2つは同じ意味です。

```haskell
p >>= \x -> q x >>= \y -> r x y
```

```haskell
do
  x <- p
  y <- q x
  r x y
```

`x <- p` は「`p` を実行してその結果を `x` という名前に束縛する」という意味です
(`IO` の `do` 構文で `line <- getLine` と書くのと全く同じ仕組みです)。
`Parser` も `Monad` インスタンスにしたことで、この `do` 構文がそのまま使えます。

## jString の実装

```haskell
jString :: Parser String JValue
jString = JString <$> (char '"' *> jString')
  where
    jString' = do
      optFirst <- optional jsonChar
      case optFirst of
        Nothing -> "" <$ char '"'
        Just first | not (isSurrogate first) ->
          (first:) <$> jString'
        Just first -> do
          second <- jsonChar
          if isHighSurrogate first && isLowSurrogate second
          then (combineSurrogates first second :) <$> jString'
          else empty
```

流れを日本語で説明すると:

1. 先頭のダブルクォートを読み飛ばす (`char '"' *>`)。
2. `jString'` で中身を再帰的に読む。
3. `optional jsonChar` で「次の JSON 文字があれば読む、無ければ `Nothing`」
   ―― `Control.Applicative.optional` は `Alternative` を使って
   `Just <$> p <|> pure Nothing` を実現する既製の関数です。
4. 文字が無ければ、閉じるダブルクォートを読んで終了 (`"" <$ char '"'`)。
   `<$` は `$>` の左右を逆にしたもので、「右側を実行するが結果は捨てて、
   左側の値を返す」という意味です。
5. 読めた文字がサロゲートでなければ、そのまま先頭にくっつけて再帰。
6. サロゲート(おそらく High Surrogate)なら、**もう1文字読んで**
   ペアとして正しいか確認し、正しければ合成、正しくなければ失敗 (`empty`)。

この5〜6のロジックは、`Applicative` だけでは書けなかったものです。`Monad` の
`do` 構文があるからこそ、「1文字目の結果を見て、2文字目を読むかどうかを
その場で決める」という分岐が書けています。

`src/Exercise/Part1/Parser.hs` に `jString` を実装してください
(サロゲート判定用の `isSurrogate` 等のヘルパー関数はすでに用意されています)。

## Monad とは結局何なのか

`Functor` は「中身を変換する」、`Applicative` は「複数の独立した処理を
組み合わせる」、そして `Monad` は「前の処理の結果に応じて、次に何をするかを
動的に決める」ためのものです。この3つは強さの順に並んでいて、
`Monad` は `Applicative` を、`Applicative` は `Functor` を包含します
(実際 `>>=` さえあれば `<*>` も `fmap` も原理的には書けます)。

## 動作確認

```
ghci> import Exercise.Part1.Parser
ghci> runParser jString "\"abhinav\""
Just ("",JString "abhinav")
ghci> runParser jString "\"\\u3042\""
Just ("",JString "\12354")
ghci> runParser jString "\"\\uD834\\uDD1E\""
Just ("",JString "\119070")
ghci> runParser jString "\"\\uD834\""
Nothing
```

最後の例(lone surrogate、ペアの相方がない)が `Nothing` になることを
確認してください。テストも実行しておきましょう。

```bash
cabal test part1
```

まだ `jNumber` 以降が未実装なので他のプロパティは失敗しますが、
`prop_genParseJString` は通るはずです。

## 次へ

[08. JSON 数値パーサ](08-jnumber.md) に進んでください。
