# 14. バックトラッキングの罠

対応する実装ファイル: `src/Exercise/Part2/Parser.hs`(セクション `docs/14-...`)

## jBool1: Part1 とほぼ同じものを書いてみる

`Parser1` を使って、Part1 の `jBool` と同じロジックの真偽値パーサを
書いてみます。

```haskell
jBool1 :: Parser1 String JValue
jBool1 =
  string1 "true" $> JBool True
    <|> string1 "false" $> JBool False
```

`src/Exercise/Part2/Parser.hs` に実装してください(Part1 の `jBool` と
中身は同じ形です)。実装できたら、わざと壊れた入力を与えてみます。

```
ghci> import Exercise.Part2.Parser
ghci> runParser1 jBool1 "trux"
Error ["Expected 'f', got 't'"]
```

**おかしいですね。** 入力は `"trux"` で、明らかに `t` から始まっているのに、
「`'f'` を期待していたが `'t'` だった」という、支離滅裂なエラーメッセージが
出てきます。

## 何が起きているか

`<|>` はバックトラッキングをします。つまり:

1. `string1 "true"` を `"trux"` に対して試す。`t`, `r`, `u` までは読めるが、
   4文字目で `e` を期待して `x` に出会い、失敗する
   (`Error ["Expected 'e', got 'x'"]`)。
2. `<|>` は「左側が失敗したら、**入力を最初の位置に巻き戻して**右側を試す」
   ので、`string1 "false"` を**もう一度 `"trux"` の先頭から**試す。
3. `string1 "false"` は1文字目 `f` を期待するが、実際の1文字目は `t` なので
   即座に失敗する (`Error ["Expected 'f', got 't'"]`)。
4. `<|>` は「右側の結果」を返すので、最終的に2の「`'f'` 期待、`'t'` だった」
   というメッセージだけが残る。1で起きていた「本当は `e` を期待していたのに
   `x` だった」という、より的確な情報は**握りつぶされて消えてしまう**。

これが「バックトラッキングとエラー報告の相性が悪い」ということの正体です。
`<|>` は「失敗した」という事実だけを引き継いで、次の選択肢をゼロから試します。
どちらの選択肢を試すべきだったかは `<|>` 自身には分からないので、
**最後に試した選択肢のエラーメッセージだけ**が残ってしまうのです。

## 解決策: 先読み(lookahead)

正しい選択肢を最初から一発で選べれば、この問題は起きません。今回のケースで
言えば、「入力の1文字目が `t` なら `"true"` を、`f` なら `"false"` を
試すべきだ」ということは、**1文字も消費せずに**判断できます。この
「消費せずに次の文字を覗き見る」操作を**先読み(lookahead)**と呼びます。

```haskell
lookahead1 :: Parser1 String Char
lookahead1 = error "TODO: lookahead1 を実装する"
```

`Parser1` の中身 `i -> ParseResult (i, o)` を思い出してください。
`lookahead1` は「入力の先頭の文字を**返す**が、入力**そのものは消費しない**」
パーサです。つまり返す `ParseResult` のタプルの1番目(残りの入力)には、
**受け取った入力をそのまま**渡します(1文字も取り除かない)。実装してください。

```haskell
jBool2 :: Parser1 String JValue
jBool2 = do
  c <- lookahead1
  JBool <$> case c of
    't' -> string1 "true" $> True
    'f' -> string1 "false" $> False
    _ ->
      throw1 $
        printf "Expected: 't' for true or 'f' for false; got '%v'" c
```

`lookahead1` で先頭の文字を覗き見て、`'t'`/`'f'`/それ以外で**バックトラッキング
せずに**分岐します。ここでも `Monad`(`do` 構文)が活躍しています。
「1文字覗いた結果を見てから、次にどのパーサを実行するか決める」という、
`Applicative` では書けない処理だからです。実装してください。

## 動作確認

```
ghci> import Exercise.Part2.Parser
ghci> runParser1 jBool2 "trux"
Error ["Expected 'e', got 'x'"]
ghci> runParser1 jBool2 "falze"
Error ["Expected 's', got 'z'"]
ghci> runParser1 jBool2 "null"
Error ["Expected: 't' for true or 'f' for false; got 'n'"]
```

`jBool1` では得られなかった「本当に起きた問題」(`Expected 'e', got 'x'`)が
正しく報告されるようになりました。

## このあとの方針

JSON の文法は幸い、**先読み1文字で次に何のパーサを試すべきか常に一意に
決まる**という性質を持っています(`n`→null, `t`/`f`→bool, `"`→文字列,
`[`→配列, `{`→オブジェクト, それ以外→数値)。そのため、このあと
すべてのパーサを「バックトラッキング (`<|>`)」から「先読み + `case`」の
スタイルに書き換えていきます。**`Alternative` インスタンスはこの後
定義しません**。バックトラッキング自体をやめるからです
(`some`/`many`/`optional` も使えなくなるので、代わりの書き方をその都度
説明します)。

## 次へ

[15. Zipper という考え方](15-zippers.md) に進んでください。
