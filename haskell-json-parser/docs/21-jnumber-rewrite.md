# 21. jNumber の書き直し

対応する実装ファイル: `src/Exercise/Part2/Parser.hs`(セクション `docs/21-...`)

図解: [JSON Number の内訳](https://claude.ai/code/artifact/f1587504-acff-4abd-9aa9-2102cef874a8#json-number)
(08 で見たものと同じ図です。整数部・小数部・指数部の関係を思い出してください)

## jUInt と jInt

Part1 では `jUInt`/`jInt'` を `Alternative`(`<|>`)で組み立てていました。
Part2 では先読みで書き直します。

```haskell
jUInt :: Parser String Integer
```

方針:

1. `lookahead` で最初の文字を見る。
2. `'0'` なら、`digit` で1文字読んで(それが `0` であることは確定している)
   `0` を返す(JSON では `0` の後には数字が続けない)。
3. それ以外の数字なら、`digits`(このあと実装)で1桁以上読み、
   `digitsToNumber` で数値に変換する。
4. 数字でなければ `throw` でエラー。
5. 全体を `` `elseThrow` "Expected an unsigned integer" `` で
   包み、失敗時の文脈を追加する。

`src/Exercise/Part2/Parser.hs` に実装してください。

```haskell
jInt :: Parser String Integer
```

`jUInt` に符号を追加したものです。`lookahead` で `'-'` かどうかを見て、
`'-'` なら `char '-' *> jUInt` した結果を `negate` する。それ以外は
そのまま `jUInt`。全体を `` `elseThrow` "Expected a signed integer" ``
で包みます。実装してください(Part1 の `jInt'`/`signInt` と実質同じ
ロジックです)。

## digits: 先読みで終わりを判定する

```haskell
digits :: Parser String [Int]
digits = ((:) <$> digit <*> digits') `elseThrow` "Expected digits"
  where
    digits' =
      safeLookahead >>= \case
        Just c | isDigit c -> (:) <$> digit <*> digits'
        _ -> return []
```

Part1 の `digits = some digit` は `Alternative` の `some`(1回以上の
繰り返し)に頼っていました。`Alternative` を使わない Part2 では、
「次の文字が数字かどうかを `safeLookahead` で確認しながら、自分で
再帰する」形に書き直します。`digits'`(内部の再帰部分)はすでに
実装されています。

- `safeLookahead` は「入力が空でも失敗しない」先読みでした(19 参照)。
  ここでは「次の文字がある上に数字でもある」場合だけ読み進め、
  そうでなければ(数字でない、または入力が尽きた)そこで終了し空リストを返す
  ―― という「1回も読めなくてもよい繰り返し」(`many` 相当)を、
  `Monad` の `do`/`>>=` で手書きしていることになります。
- 外側の `digits` は「最低1回は `digit` を呼ぶ」(`some` 相当)ことを、
  `(:) <$> digit <*> digits'` という形(1個読んでから、0回以上の
  繰り返しにつなげる)で表現しています。

`digits` 全体はすでに実装されています。読んで理解を確認してください
(実装する対象は `jFrac`/`jExp` などこの後の項目です)。

## jFrac と jExp

```haskell
jFrac :: Parser String [Int]
jFrac = error "TODO: jFrac を実装する (elseThrow を使う)"
```

`.` を読んでから `digits` を読むだけです。全体を
`` `elseThrow` "Expected a fraction" `` で包みます。実装してください。

```haskell
jExp :: Char -> Parser String Integer
```

引数の `Char` は `'e'` か `'E'`(すでに `jNumber` 側でどちらが来たか
確認済みという想定で渡されます)。その文字を読んでから、符号
(`'-'`/`'+'`/省略)を先読みで判定して `jUInt` を読みます。全体を
`` `elseThrow` "Expected an exponent" `` で包みます。実装してください。

## jNumber: モナディックスタイルでの合体

```haskell
jNumber :: Parser String JValue
```

Part1 では `jInt`/`jIntFrac`/`jIntExp`/`jIntFracExp` という4つの
パーサを別々に作り、`<|>` で束ねていました。Part2 では、`do` 構文を
使って「まず整数部を読み、その後どうなっているかを都度先読みで確認しながら、
必要な分だけ追加で読む」という**1つの連続した手続き**として書きます。

```haskell
jNumber = do
  i <- jInt
  safeLookahead >>= \case
    Just '.' -> do
      f <- jFrac
      safeLookahead >>= \case
        Just c' | isExpSym c' -> JNumber i f <$> jExp c'   -- 整数+小数+指数
        _                     -> pure $ JNumber i f 0       -- 整数+小数
    Just c | isExpSym c -> JNumber i [] <$> jExp c           -- 整数+指数
    _                   -> pure $ JNumber i [] 0             -- 整数のみ
  where
    isExpSym c = c == 'e' || c == 'E'
```

型のことを気にせず日本語で読むと:「整数部を読む。次の文字が `.` なら
小数部も読み、そのあとさらに `e`/`E` があれば指数部も読む。`.` がなく
最初から `e`/`E` なら指数部だけ読む。どちらもなければ整数のみ」―― これは
08 で見た「4通りの組み合わせ」と同じ内容を、**先読みで実際に何が
続いているかを都度確認しながら**1つの流れで表現したものです。
`Alternative` に頼らず `Monad` だけでこの分岐を書けることを確認してください。

`src/Exercise/Part2/Parser.hs` に実装してください。

## 動作確認

```
ghci> import Exercise.Part2.Parser
ghci> runParser jNumber "01"
Result ("1",JNumber 0 [] 0)
ghci> runParser jNumber "44.3e-7"
Result ("",JNumber 44 [3] (-7))
ghci> runParser jNumber "-a"
Error [...]
```

```bash
cabal test part2
```

`prop_genParseJString` と `prop_genParseJNumber` が通れば OK です。

## 次へ

[22. jArray / jObject の書き直し](22-jarray-jobject-rewrite.md) に
進んでください。
