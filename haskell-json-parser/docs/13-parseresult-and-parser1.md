# 13. ParseResult と Parser1

対応する実装ファイル: `src/Exercise/Part2/Parser.hs`(セクション `docs/13-...`)

## なぜ「1」が付くのか

`src/Exercise/Part2/Parser.hs` には `Parser1`, `jBool1`, `jBool2` のように
末尾に数字が付いた名前が出てきます。これは Part1 の `digit1`/`digit2`/`digit3`
と同じ意味合いで、「最終形ではない、途中経過のバージョン」という印です。
このステップではまず**バックトラッキングは残したまま**、エラー報告の
仕組みだけを先に導入します。バックトラッキングをやめて先読みに切り替えるのは
次のステップ (14) です。段階を分けることで、一度に変える範囲を小さくします。

## ParseResult: Maybe の代わり

```haskell
data ParseResult a = Error [String] | Result a
```

`Maybe a` の `Nothing`/`Just a` に相当するのが `Error [String]`/`Result a`
です。`Error` がエラーメッセージの**リスト**を持っている点がポイントです。
パースが失敗して呼び出し元に伝播していく過程で、メッセージがどんどん
積み増されていく(=文脈の履歴になる)ようにするためです(12 で見た
「一番下から読むと文脈が積み上がっている」出力を思い出してください)。

`Show`/`Functor`/`Applicative` インスタンスは既に実装されています
(`src/Exercise/Part2/Parser.hs` を読んで、`Maybe` の対応するインスタンスと
見比べてみてください。中身はほぼ同じ形をしているはずです)。

```haskell
instance Functor ParseResult where
  fmap = error "TODO: ..."

instance Applicative ParseResult where
  pure = error "TODO: ..."
  (<*>) = error "TODO: ..."
```

`Maybe` の `Functor`/`Applicative` インスタンス(標準ライブラリにある)と
まったく同じパターンで書けます。`Error errs` はどんな操作をしても
`Error errs` のまま(中身を素通りする)、`Result x` の場合だけ処理する、
という形です。実装してください。

## Parser1: エラー報告版パーサ(暫定版)

```haskell
newtype Parser1 i o
  = Parser1 {runParser1 :: i -> ParseResult (i, o)}
```

Part1 の `Parser` の `Maybe` を `ParseResult` に差し替えただけです。
`Functor`/`Applicative`/`Alternative`/`Monad` のインスタンスも、
Part1 で書いたものとほぼ同じ形になります。

```haskell
instance Functor (Parser1 i) where
  fmap = error "TODO: ..."

instance Applicative (Parser1 i) where
  pure = error "TODO: ..."
  (<*>) = error "TODO: ..."

instance Alternative (Parser1 i) where
  empty = error "TODO: ..."
  (<|>) = error "TODO: ..."

instance Monad (Parser1 i) where
  (>>=) = error "TODO: ..."
```

Part1 の対応するインスタンス(`src/Exercise/Part1/Parser.hs` または
`solutions/Solutions/Part1.hs`)を見比べながら、`Maybe` の
`Nothing`/`Just` を `ParseResult` の `Error`/`Result` に読み替えて
実装してください。1点だけ注意が必要なのが `Alternative` の `empty` です。

```haskell
empty = Parser1 $ const $ Error ["Unknown error."]
```

`Maybe` の `empty`(= `Nothing`)には「理由」がありませんが、
`ParseResult` の `Error` は理由(メッセージ)を持つ型なので、`empty` にも
何かメッセージを与える必要があります。ここでは仮に `"Unknown error."`
としています(後のステップで、`empty` に頼らずちゃんと意味のあるメッセージを
都度用意する方式に切り替わります)。

## エラーを投げるヘルパー

```haskell
parseError1 :: String -> ParseResult a
parseError1 err = Error [err]

throw1 :: String -> Parser1 String o
throw1 = Parser1 . const . parseError1
```

これらはすでに実装されています。`throw1 "何か理由"` は「常に、指定した
理由で失敗するパーサ」を作ります。

## satisfy1 と string1

```haskell
satisfy1 ::
  (Char -> Bool) -> (Char -> String) -> Parser1 String Char
satisfy1 predicate mkError = Parser1 $ \case
  (c : cs) | predicate c -> Result (cs, c)
  (c : _) -> parseError1 (mkError c)
  _ -> parseError1 "Empty input"
```

Part1 の `satisfy` との違いは、2つ目の引数 `mkError :: Char -> String` です。
「実際に読んだ文字を受け取って、それに応じたエラーメッセージを作る関数」を
外から渡せるようになっています。これにより `char1` は:

```haskell
char1 :: Char -> Parser1 String Char
char1 c = satisfy1 (== c) $ printf "Expected '%v', got '%v'" c
```

`Text.Printf.printf` は C言語などでおなじみの書式付き文字列生成関数です。
`printf "Expected '%v', got '%v'" c :: Char -> String` のように、
`%v` の数だけ引数を追加で受け取る関数になります(`c` はすでに1つ目の
`%v` に束縛済みなので、残りの1引数を受け取る関数が返ります)。

`satisfy1` を実装してください(`src/Exercise/Part2/Parser.hs` を編集)。
`string1` は Part1 の `string1`(および `Applicative` を使った `string`)と
同じ考え方で書けます。

```haskell
string1 :: String -> Parser1 String String
string1 "" = pure ""
string1 (c : cs) = (:) <$> char1 c <*> string1 cs
```

実装してください。

## 動作確認

```
ghci> import Exercise.Part2.Parser
ghci> runParser1 (string1 "abc") "abc"
Result ("","abc")
ghci> runParser1 (string1 "abc") "abx"
Error ["Expected 'c', got 'x'"]
ghci> runParser1 (string1 "abc") ""
Error ["Empty input"]
```

## 次へ

[14. バックトラッキングの罠](14-backtracking-problem.md) に進んでください。
