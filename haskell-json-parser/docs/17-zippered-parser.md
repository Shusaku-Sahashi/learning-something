# 17. Zipper 対応版 Parser

対応する実装ファイル: `src/Exercise/Part2/Parser.hs`(セクション `docs/17-...`)

## 最終版の Parser 型

これまでの2つの寄り道(`ParseResult`、`TextZipper`)を合体させて、
Part2 で最終的に使う `Parser` 型を定義します。

```haskell
newtype Parser i o = Parser
  { runParser_ :: TextZipper i -> ParseResult (TextZipper i, o)
  }
```

Part1 の `Parser i o = i -> Maybe (i, o)` と見比べてください。
「入力の型」が `i` から `TextZipper i` に、「結果の型」が `Maybe` から
`ParseResult` に変わっただけで、骨組みは同じです。

`runParser_`(アンダースコア付き)という名前になっているのは、
外部から呼び出すときは生の `TextZipper` ではなく、素直に `String` を
渡したいからです。そのための薄いラッパーがすでに用意されています。

```haskell
runParser :: Parser String o -> String -> ParseResult (String, o)
runParser parser input =
  case runParser_ parser (textZipper $ lines input) of
    Error errs -> Error errs
    Result (restZ, output) -> Result (leftOver restZ, output)
  where
    leftOver tz = concat (tzRight tz : tzBelow tz)
```

`String` を `lines` で行に分割して `textZipper` に変換し、パース後は
逆に「残りの `TextZipper`」を「残りの `String`」(カーソルの右側 + 下の行を
全部つなげたもの)に変換し直しています。今後 GHCi や `runParser` を
使うときは、この`runParser`(アンダースコアなし)の方を使います。

## Functor / Applicative / Monad

```haskell
instance Functor (Parser i) where
  fmap = error "TODO: ..."

instance Applicative (Parser i) where
  pure = error "TODO: ..."
  (<*>) = error "TODO: ..."

instance Monad (Parser i) where
  (>>=) = error "TODO: ..."
```

驚くかもしれませんが、実装のロジック自体は Part1 の `Parser` と
**まったく同じ**です。`Maybe` を `ParseResult` に読み替えるだけです。
`ParseResult` の `Functor`/`Applicative` インスタンス(13 で実装したもの)
がすでに「`Error`/`Result` の場合分け」を肩代わりしてくれるので、
`Parser i` の側のコードは「タプルの2番目を変換する」「1つ目の結果を
2つ目に渡す」という Part1 と同じ形で書けます。

`src/Exercise/Part2/Parser.hs` に実装してください。困ったら、
`src/Exercise/Part1/Parser.hs`(または `solutions/Solutions/Part1.hs`)の
対応するインスタンスと、13 で書いた `ParseResult` の `Functor`/
`Applicative` の実装を見比べてみてください。

**注意**: この `Parser` には `Alternative` インスタンスを定義しません。
14 で確認した通り、バックトラッキング(`<|>`)とエラー報告の相性が
悪いからです。このあとすべてのパーサは「先読み + `case`」のスタイルで
書きます。

## 動作確認

インスタンスの実装だけではまだ目に見える動作確認はできません
(`lookahead`/`char` などの具体的なパーサは次のステップから)。
コンパイルが通ることだけ確認しておきましょう。

```bash
cabal build
```

## 次へ

[18. 位置情報付きエラーメッセージ](18-errors-with-position.md) に
進んでください。
