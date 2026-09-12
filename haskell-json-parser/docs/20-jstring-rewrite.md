# 20. jString の書き直し

対応する実装ファイル: `src/Exercise/Part2/Parser.hs`(セクション `docs/20-...`)

Part2 で最も複雑なパーサです。急がずに、日本語の説明と型シグネチャを
何度も見比べながら進めてください。

## jsonChar: 先読みベースの1文字パーサ

Part1 の `jsonChar` は `<|>` を8つ並べたバックトラッキング方式でした。
Part2 では先読みで書き直します。

```haskell
jsonChar :: Parser String (Char, Int)
```

戻り値が `Char` だけでなく `(Char, Int)` になっている点に注目してください。
2つ目の `Int` は「**入力から実際に何文字消費したか**」です。例えば
普通の1文字なら `1`、`\n` のようなエスケープは `2`(バックスラッシュ+n)、
`\u3042` のようなユニコード指定は `6`(`\`, `u`, 4桁の16進数)。
なぜ消費文字数が必要なのかは、このあと `jFirstChar` で説明します。

実装方針:

1. `lookahead` で最初の文字を覗く。
2. `\\`(バックスラッシュ)なら、それを1文字消費してから、
   `escapedChar` でエスケープシーケンスの中身を読む。
3. それ以外なら、`otherChar`(すでに用意されている、`satisfy` ベースの
   ヘルパー)で普通の文字として読み、消費文字数 `1` とペアにする。

`escapedChar` の中でも、もう一度 `lookahead` して分岐します
(`"`, `\`, `/`, `b`, `f`, `n`, `r`, `t` はそれぞれ対応する1文字に、
`u` の場合だけ4桁の16進数を読んで文字コードに変換、`digitsToNumber` は
実装済み)。それ以外の文字が来たら `throw` で
`"Invalid escaped character: '%v'"` のエラーを出します。

`src/Exercise/Part2/Parser.hs` の `where` 節の骨組み(`escapedChar`,
`unicodeChar`, `hexDigit`, `otherChar`, `isQuoteEscapeOrControl` の一部は
実装済み)を活用しながら、`jsonChar` 本体を実装してください。

## jString と jString'

```haskell
jString :: Parser String JValue
jString = JString <$> (char '"' *> jString')
```

これは実装済みです(開きのダブルクォートを読んで `jString'` に委譲するだけ)。

```haskell
jString' :: Parser String String
```

Part1 の `optional jsonChar` は `Alternative` に頼っていました。Part2 では
`Alternative` を使わないので、代わりに `lookahead` で明示的に
「次の文字はダブルクォートか、それとも中身が続くか」を判定します。

実装方針:

1. `lookahead` で次の文字を見る(`elseThrow` で
   `"Expected rest of a string"` という文脈を追加しておく)。
2. その文字が `'"'` なら、実際に1文字消費して(`char '"'`)、
   空文字列を返す(文字列の終わり)。
3. それ以外なら `jFirstChar` に処理を委譲する。

実装してください。

## jFirstChar: サロゲート判定の入り口

```haskell
jFirstChar :: Parser String String
```

`jsonChar` で1文字読み、その結果に応じて3通りに分岐します
(`MultiWayIf` 拡張の `if | 条件1 -> ... | 条件2 -> ... | otherwise -> ...`
という書き方が使えます。普通の `case` で書いても構いません)。

1. サロゲートでなければ、そのまま先頭にくっつけて `jString'` を再帰呼び出し。
2. High Surrogate なら、`jSecondChar` に処理を渡す(2文字目を読みに行く)。
3. それ以外(Low Surrogate が単独で出てきた、など不正な場合)は、
   `pushback` で読んだ分を巻き戻してから `throw` でエラーにする。

### なぜ pushback が必要なのか

3のケースを考えてみます。`jsonChar` はすでに1文字(場合によっては
`\uXXXX` で6文字)を読み進めてしまっています。しかしこの文字は
「単独の Low Surrogate」という不正な文字であり、エラーメッセージには
**この文字が現れた位置**を報告したいはずです。ところがパーサはすでに
その文字の**先**まで進んでしまっているので、何もしなければエラー位置が
1文字分ずれてしまいます。

```haskell
pushback :: Int -> Parser String ()
pushback count = Parser $ \input ->
  Result (iterate moveBackByOne input !! count, ())
```

これはすでに実装されています。`jsonChar` が返してくれた「消費文字数」
(`Int`)を使って、`moveBackByOne`(16 で実装したもの)をその回数だけ
繰り返し適用し、**エラーを報告したい文字の直前まで巻き戻して**から
`throw` する、という仕組みです。これが `jsonChar` がわざわざ
`(Char, Int)` を返していた理由です。

`src/Exercise/Part2/Parser.hs` に `jFirstChar` を実装してください。

## jSecondChar: サロゲートペアの2文字目

```haskell
jSecondChar :: Char -> Parser String String
```

引数の `Char` は1文字目(High Surrogate)です。

1. `jsonChar` で2文字目を読む(`elseThrow` で
   `"Expected a second character of a surrogate pair"` という文脈を
   追加。1文字目とは違い、ここは `lookahead` の代わりに直接読みに行きます。
   サロゲートペアの相方が無いのは常にエラーだからです)。
2. 2文字目が Low Surrogate なら、`combineSurrogates`(実装済み)で
   1文字目と合成し、`jString'` を再帰呼び出しして続きを読む。
3. そうでなければ、`jFirstChar` の3と同様に `pushback` してから
   `throw` でエラーにする。

実装してください。

## 動作確認

```
ghci> import Exercise.Part2.Parser
ghci> runParser jsonChar "a"
("",('a',1))
ghci> runParser jsonChar "\\b"
("",('\b',2))
ghci> runParser jsonChar "\\u0040"
("",('@',6))
ghci> runParser jString "\"abc\""
("","abc")
ghci> runParser jString "\"\\uD834\\uDD1E\""
("","𝄞")
ghci> runParser jString "\"\\uD834\""
Did not except '"', '\' or control characters, got '"' at line 1, column 8: \uD834"
                                                                                  ↑
→ Expected a second character of a surrogate pair at line 1, column 8: \uD834"
                                                                             ↑
```

```bash
cabal test part2
```

`prop_genParseJString` が通れば OK です。

## 次へ

[21. jNumber の書き直し](21-jnumber-rewrite.md) に進んでください。
