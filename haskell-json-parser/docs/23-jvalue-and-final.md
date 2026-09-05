# 23. jValue と最終テスト

対応する実装ファイル: `src/Exercise/Part2/Parser.hs`(セクション `docs/23-...`)

## jValue: 先読み1文字で振り分ける

```haskell
jValue :: Parser String JValue
jValue = jValue' `surroundedBy` spaces
  where
    jValue' =
      lookahead >>= \case
        'n'  -> jNull   `elseThrow` "Expected null"
        't'  -> jBool   `elseThrow` "Expected true"
        'f'  -> jBool   `elseThrow` "Expected false"
        '\"' -> jString `elseThrow` "Expected a string"
        '['  -> jArray  `elseThrow` "Expected an array"
        '{'  -> jObject `elseThrow` "Expected an object"
        c | c == '-' || isDigit c ->
              jNumber `elseThrow` "Expected a number"
        c -> throw $ printf "Unexpected character: '%v'"
                    $ showCharForErrorMsg c
```

Part1 の `jValue` は6つのパーサを `<|>` で並べるだけでした。Part2 では、
`lookahead` で先頭1文字を見て、**その1文字だけで次にどのパーサを呼ぶか
確定させます**。JSON の文法は、先頭1文字だけで「これは配列だ」
「これは文字列だ」と一意に決まるように作られているため、この方式が
成り立ちます(`t`/`f` はどちらも真偽値なので `jBool` に合流しますが、
それぞれ別のエラーメッセージ文脈 `"Expected true"`/`"Expected false"`
を添えている点に注目してください ―― 先読みなので、実際に `jBool` の
中でさらに `t`/`f` の分岐が起きます)。

数字の場合だけ `c == '-' || isDigit c` というガード付きパターンに
なっているのは、JSON の数値が `-` から始まる場合と数字から直接始まる
場合の両方があるためです。どの文字にも当てはまらなければ、
`"Unexpected character: '%v'"` というエラーで失敗させます。

`src/Exercise/Part2/Parser.hs` に実装してください。この1つの `case` 式が、
01 で見た「JSON Value は6種類のいずれか」という定義と、ほぼ1対1で
対応していることを確認してください。

## parseJSON: Either 版

```haskell
parseJSON :: String -> Either String JValue
parseJSON s = case runParser jValue s of
  Result ("", j) -> Right j
  Result (i, _)  -> Left $ "Leftover input: " <> i
  err@(Error _)  -> Left $ show err
```

Part1 の `parseJSON` は `Maybe JValue` を返していましたが、Part2 では
`Either String JValue` です。`Left` の中身がエラーメッセージ(文字列)を
持てるようになった、というのがこの書き換えの核心です。

- `jValue` を実行して、残りの入力が空文字列なら成功(`Right j`)。
- 残りの入力があれば(10 で見た「読み切れていない」ケース)、
  それも1つのエラーとして報告する。
- パース自体が失敗していれば(`Error`)、その `ParseResult` の
  `Show` インスタンス(13 で読んだ、逆順に積み上げて表示するもの)を
  使ってメッセージ文字列に変換する。

実装してください。

```haskell
printResult :: Either String JValue -> IO ()
printResult = putStrLn . either ("ERROR:\n" <>) (("RESULT:\n" <>) . show)
```

これは実装済みです。`Data.Either.either :: (a -> c) -> (b -> c) -> Either a b -> c`
は「`Left`/`Right` それぞれに適用する関数を渡して、両方まとめて処理する」
という、`Either` に対する `case` 式の糖衣的な書き方です。

## 最終動作確認

12 で見た「目指す出力」を、実際に自分の実装で再現してみましょう。

```
ghci> import Exercise.Part2.Parser
ghci> printResult $ parseJSON "[{\"c\"\t:\n  \n  \t[\r\"\\g\"]}]"
ERROR:
Invalid escaped character: 'g' at line 3, column 8: ...
→  Expected a string at line 3, column 6: ...
→  Expected a JSON value at line 3, column 6: ...
→  Expected an array at line 3, column 4: ...
...
ghci> printResult $ parseJSON "[{\"c\"\t:\n  \n  \t[\r\"\\n\"]}]"
RESULT:
[{"c": ["\n"]}]
```

エラーの積み重ね(`→` で始まる行)が、パースが失敗するまでにたどった
文脈の履歴になっていることを確認してください。

## テストで全体を検証する

```bash
cabal test part2
```

5つのプロパティすべてが `+++ OK, passed 100 tests.` になれば、
Part2 も完成です。

念のため、模範解答も引き続き通ることを確認しておきましょう。

```bash
cabal test solutions-part1 solutions-part2
```

## 次へ

[24. 振り返りと発展課題](24-conclusion.md) に進んでください。
