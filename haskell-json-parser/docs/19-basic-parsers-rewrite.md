# 19. 基本パーサの書き直し

対応する実装ファイル: `src/Exercise/Part2/Parser.hs`(セクション `docs/19-...`)

## lookahead と safeLookahead

14 で導入した「先読み」を、最終版の `Parser` で書き直します。

```haskell
lookahead :: Parser String Char
```

`currentChar`(16 で実装した `TextZipper` の関数)で現在位置の文字を
覗きます。文字があればそれを返す(入力は消費しない = `move` は呼ばない)。
無ければ `"Empty input"` というメッセージで失敗させます
(`parseError`/`throw` を使います)。実装してください。

```haskell
safeLookahead :: Parser String (Maybe Char)
```

`lookahead` とほぼ同じですが、**入力が空でも失敗しません**。代わりに
`Maybe Char` として `Nothing`/`Just` を返します。「あるかもしれないし
無いかもしれないものを覗く」場面(このあと「配列の要素がまだ続くか」
「文字列がまだ続くか」の判定などで頻出します)で使います。実装してください。

## satisfy: 消費して確かめる

```haskell
satisfy :: (Char -> Bool) -> String -> Parser String Char
```

`lookahead`/`safeLookahead` が「覗くだけ」だったのに対し、`satisfy` は
Part1 と同じく「条件を満たしていたら実際に1文字消費する」パーサです。
2つ目の引数(`String`)は、失敗したときのエラーメッセージの元になる
「期待していたものの説明」です(13 の `satisfy1` と同じ設計)。

実装方針:

1. `currentChar` で現在位置の文字を取得する。
2. 文字があり、かつ述語を満たすなら、`move`(16 で実装したもの)で
   1文字進めた `TextZipper` と、その文字を結果として返す。
3. 文字はあるが述語を満たさないなら、`"expectation, got 'X'"`
   というメッセージで失敗させる。
4. 入力が空なら、`"expectation, but the input is empty"` という
   メッセージで失敗させる。

`src/Exercise/Part2/Parser.hs` に実装してください。`char`/`digit`/`string`
はこの `satisfy` の上に構築されており、すでに実装済みです。

```haskell
char :: Char -> Parser String Char
char c = satisfy (== c) $ printf "Expected '%v'" $ showCharForErrorMsg c

digit :: Parser String Int
digit = digitToInt <$> satisfy isDigit "Expected a digit"

string :: String -> Parser String String
string "" = pure ""
string (c : cs) = (:) <$> char c <*> string cs
```

`string` が Part1 とまったく同じ形(`(:) <$> char c <*> string cs`)で
書けていることを確認してください。`Applicative` の力は、パーサの内部実装が
変わっても揺らぎません。

## jNull と jBool

```haskell
jNull :: Parser String JValue
```

Part1 の `jNull`(`string "null" $> JNull`)とロジックは同じです。
使う `string`/`$>` が Part2 版に変わっただけです。実装してください。

```haskell
jBool :: Parser String JValue
```

14 の `jBool2` と同じ、先読みベースの実装です。実装してください。

## 動作確認

```
ghci> import Exercise.Part2.Parser
ghci> runParser lookahead "abc"
("abc",'a')
ghci> runParser lookahead ""
Empty input at line 1, column 1:
                                 ↑
ghci> runParser (string "abh") "abhinav"
("inav","abh")
ghci> runParser (string "abc") "abhinav"
Expected 'c', got 'h' at line 1, column 3: abhinav
                                             ↑
```

(`Show (ParseResult a)` は `Result`/`Error` というコンストラクタ名を表示に含めません
―― 13 で見た通り、中身だけをそのまま返す実装だからです。)

```bash
cabal test part2
```

まだ大半のプロパティは失敗しますが、コンパイルが通ることを確認してください。

## 次へ

[20. jString の書き直し](20-jstring-rewrite.md) に進んでください。
