# 22. jArray / jObject の書き直し

対応する実装ファイル: `src/Exercise/Part2/Parser.hs`(セクション `docs/22-...`)

## ヘルパー: surroundedBy, separatedBy, spaces

```haskell
surroundedBy :: Parser i a -> Parser i b -> Parser i a
surroundedBy parser1 parser2 = parser2 *> parser1 <* parser2
```

これは実装済みです。Part1 と全く同じ形です(`Applicative` の `*>`/`<*` は
`Parser` の中身が何であっても同じように使えます)。

```haskell
separatedBy :: Parser String v -> Char -> String -> Parser String [v]
```

Part1 の `separatedBy` は「区切り文字を読むパーサ」自体を引数に取り、
`many`(`Alternative`)で繰り返していました。Part2 では `Alternative` を
使わないので、区切り文字は**具体的な `Char`** で受け取り、
`safeLookahead` で「次が区切り文字かどうか」を見ながら自分で再帰します。
3つ目の引数(`String`)は要素のパース失敗時に使うエラーメッセージです。

実装方針:

1. `parser`(1つの要素)を読む。`` `elseThrow` errMsg `` で文脈を追加。
2. `safeLookahead` で次の文字を見る。
3. 次の文字が `sepChar` と一致するなら、区切り文字を1文字消費してから、
   `separatedBy parser sepChar errMsg` を再帰呼び出しし、その結果の先頭に
   今読んだ要素をくっつける。
4. 一致しない(または入力が尽きた)なら、今読んだ要素だけを1要素のリストに
   して返す(再帰終了)。

`src/Exercise/Part2/Parser.hs` に実装してください。

```haskell
spaces :: Parser String String
```

同じく `safeLookahead` を使い、「空白文字である限り読み進める」を
自分で再帰する形に書き直します(`many (char ' ' <|> ...)` の
`Alternative` を使わない版)。実装してください。

## jArray

```haskell
jArray :: Parser String JValue
jArray =
  JArray <$> do
    _ <- char '[' <* spaces
    c <- lookahead `elseThrow` "Expected a JSON value or ']'"
    case c of
      ']' -> [] <$ char ']'
      _ ->
        separatedBy jValue ',' "Expected a JSON value"
          <* satisfy (== ']') "Expected ',' or ']'"
```

Part1 の `jArray` は `Applicative` だけで(`separatedBy \`surroundedBy\` spaces`
という1つの式で)書けていました。Part2 では**先読みが必要**になったため、
`do` 構文を使った手続き的なスタイルに変わっています。流れ:

1. `[` を読み、続く空白を読み飛ばす。
2. 次の文字を先読みする。`]` なら(空配列)、それを消費して終了。
3. `]` でなければ、`jValue` の並びを `separatedBy` で読み、最後に `]` を
   確認する(`satisfy (== ']') "Expected ',' or ']'"` は「カンマでも
   閉じ括弧でもない何かが来た」場合に適切なエラーメッセージを出すため)。

`src/Exercise/Part2/Parser.hs` に実装してください。

## jObject

```haskell
jObject :: Parser String JValue
jObject =
  JObject <$> do
    _ <- char '{' <* spaces
    c <- lookahead `elseThrow` "Expected a JSON value or '}'"
    case c of
      '}' -> [] <$ char '}'
      _ ->
        separatedBy pair ',' "Expected an object key-value pair"
          <* satisfy (== '}') "Expected ',' or '}'"
  where
    pair = (\ ~(JString s) j -> (s, j)) <$> key <* char ':' <*> value
    key = (jString `surroundedBy` spaces) `elseThrow` "Expected an object key"
    value = jValue `elseThrow` "Expected an object value"
```

`jArray` とほぼ同じ構造で、記号が `{`/`}` になり、要素が `jValue` 単体
ではなく `pair`(キーと値のペア)になっただけです。`pair`/`key`/`value`
の部分は `Applicative`(`<$>`/`<*>`/`<*`)だけで書けることに注目してください
―― キーを読んでから値を読むまでの間に「先読みで分岐する」必要が
ないからです(先読みが必要なのは「配列やオブジェクト全体が空かどうか」
「まだ要素が続くかどうか」という部分だけです)。実装してください。

## 動作確認

```
ghci> import Exercise.Part2.Parser
ghci> runParser jArray "[1,      \"hello\", \n3.5,  null, [false,true]]"
Result ("",JArray [...])
ghci> runParser jArray "[0,]"
Error [...]
ghci> runParser jObject "{\"a\": 1}"
Result ("",JObject [("a",JNumber 1 [] 0)])
ghci> runParser jObject "{\"a\":}"
Error [...]
```

```bash
cabal test part2
```

`prop_genParseJArray`/`prop_genParseJObject` が通れば OK です。

## 次へ

[23. jValue と最終テスト](23-jvalue-and-final.md) に進んでください。
