# 10. jValue と parseJSON

対応する実装ファイル: `src/Exercise/Part1/Parser.hs`(セクション `docs/10-...`)

## jValue: 6つの選択肢

いよいよ「任意の JSON 値」をパースする関数です。JSON の値は6種類のいずれかで
した。

```haskell
jValue :: Parser String JValue
jValue = jValue' `surroundedBy` spaces
  where
    jValue' =   jNull
            <|> jBool
            <|> jString
            <|> jNumber
            <|> jArray
            <|> jObject
```

これまで作った6つのパーサを `<|>` で並べて、前後の空白を許容するだけです。
`01-json-and-parsing.md` で見た「JSON の値は6種類のいずれか」という定義と、
このコードがほぼ1対1で対応していることを確認してください。実装したら、
`09` で保留にしていた `jArray`/`jObject` の中の `jValue` 参照も含めて
すべて解決し、プロジェクト全体がコンパイルできるようになります。

## parseJSON: エントリーポイント

```haskell
parseJSON :: String -> Maybe JValue
parseJSON s = case runParser jValue s of
  Just ("", j) -> Just j
  _            -> Nothing
```

`jValue` を実行して、**残りの入力が空文字列であること**を確認してから
成功とみなします。なぜこのチェックが必要かというと、`jValue` 自体は
「先頭から読めるだけ読んで成功」を返すからです。例えば `"123abc"` を
`jValue` に通すと `Just ("abc", JNumber 123 [] 0)` のように、`abc` を
残したまま成功してしまいます。JSON テキスト全体としては不正な入力ですが、
`jValue` だけを見ていては気づけません。`parseJSON` で「全部読み切れたか」
を最後に確認することで、この問題を防いでいます。

`parseJSON` を実装してください。

## 動作確認

ここまでで Part1 のすべてのパーサが揃いました。GHCi で実際に JSON を
パースしてみましょう。

```
ghci> import Exercise.Part1.Parser
ghci> parseJSON "{\"a\": 1, \"b\": [false, null]}"
Just {"a": 1, "b": [false, null]}
ghci> parseJSON "{\"a\": 1"
Nothing
ghci> parseJSON "[1, 2, 3] garbage"
Nothing
```

(表示が `Just {"a": 1, ...}` のように JSON っぽく見えるのは、`Json.Value` の
`Show` インスタンスのおかげです。02 で読んだ内容を思い出してください。)

## テストで全体を検証する

```bash
cabal test part1
```

5つのプロパティすべて(`prop_genParseJString`, `prop_genParseJNumber`,
`prop_genParseJArray`, `prop_genParseJObject`, `prop_genParseJSON`)が
`+++ OK, passed 100 tests.` と表示されれば、Part1 は完成です。

もし失敗するプロパティがあれば、表示される反例(counterexample)を手がかりに
デバッグしてください。QuickCheck は失敗した入力を「できるだけ単純な形」に
縮小 (shrink) してから見せてくれるので、元の複雑な JSON よりずっと
デバッグしやすいはずです。

## 次へ

[11. Part1 の振り返り](11-part1-wrapup.md) に進んでください。
