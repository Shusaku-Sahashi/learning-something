# 08. JSON 数値パーサ

対応する実装ファイル: `src/Exercise/Part1/Parser.hs`(セクション `docs/08-...`)

新しい型クラスは出てきません。ここまでの `Functor`/`Applicative`/`Alternative`/
`Monad` を組み合わせて、JSON の数値を表現する少し込み入った文法を実装します。

図解: [JSON Number の内訳](https://claude.ai/code/artifact/f1587504-acff-4abd-9aa9-2102cef874a8#json-number)
(整数部・小数部・指数部の組み合わせパターンを図にしたものです。手を動かす前に
一度眺めておくと見通しが良くなります)

## 符号なし整数: jUInt

`01-json-and-parsing.md` で確認した通り、JSON の整数部には
「先頭ゼロは単独の `0` を除いて禁止」というルールがあります。

```haskell
jUInt :: Parser String Integer
jUInt =   (\d ds -> digitsToNumber 10 0 (d:ds)) <$> digit19 <*> digits
      <|> fromIntegral <$> digit
```

- `digit19 :: Parser String Int`(すでに実装済み)は「`1`〜`9` の数字」を
  読むパーサです。`0` を除外しているのがポイントです。
- `digits :: Parser String [Int]` は「1桁以上の数字の並び」を読みます。
  `Control.Applicative.some :: Alternative f => f a -> f [a]` は
  「同じパーサを1回以上繰り返し、結果をリストにまとめる」既製の関数です
  (`Alternative` があると手に入る道具の1つです)。`digits = some digit` を
  実装してください。
- 1つ目の選択肢(`<|>` の左側)は「`1`〜`9` の数字1つ + それに続く0個以上の
  数字」= 2桁以上、または先頭が `0` でない1桁の整数です。
- 2つ目の選択肢は「`0`〜`9` の数字1つだけ」= 単独の `0`、または
  1桁の整数(1つ目の選択肢がマッチしなかった場合の残り)。

`jUInt` を実装してください。

## 符号付き整数: jInt'

```haskell
jInt' :: Parser String Integer
jInt' = signInt <$> optional (char '-') <*> jUInt
```

`optional (char '-')` は「`-` があれば `Just '-'`、無ければ `Nothing`」を
返します(`07` で説明した `Control.Applicative.optional` です)。`signInt`
(すでに実装済み)がその `Maybe Char` を見て符号を反映します。実装してください。

## 小数部と指数部

```haskell
jFrac :: Parser String [Int]
jFrac = char '.' *> digits

jExp :: Parser String Integer
jExp = (char 'e' <|> char 'E')
  *> (signInt <$> optional (char '+' <|> char '-') <*> jUInt)
```

小数点の後、指数記号の後は、それぞれ `digits`/`jUInt` を読むだけです。
指数部だけ `+` の符号も許される点に注意してください(整数部には `+` は
許されません)。実装してください。

## 4通りの組み合わせ

JSON の数値は「整数部は必須、小数部と指数部は任意」なので、4通りの形が
あります。それぞれに対応するパーサを用意します。

```haskell
jInt :: Parser String JValue
jInt = JNumber <$> jInt' <*> pure [] <*> pure 0

jIntExp :: Parser String JValue
jIntExp = JNumber <$> jInt' <*> pure [] <*> jExp

jIntFrac :: Parser String JValue
jIntFrac = (\i f -> JNumber i f 0) <$> jInt' <*> jFrac

jIntFracExp :: Parser String JValue
jIntFracExp = (\ ~(JNumber i f _) e -> JNumber i f e) <$> jIntFrac <*> jExp
```

- `JNumber` は3引数のコンストラクタなので `<$>`/`<*>` を2回重ねて適用します。
- 省略された部分には `pure []`(小数部なし)や `pure 0`(指数部なし)という
  「何も消費せず決まった値を返す」パーサを当てはめます。
- `jIntFracExp` だけ、先に `jIntFrac` を実行してその結果(`JNumber i f 0`)を
  受け取り、`i` と `f` だけ取り出して `e` と組み合わせ直しています。
  `~(JNumber i f _)` の `~` は**遅延パターン**(lazy pattern)で、
  「このパターンマッチは実際に値が必要になるまで(ここでは `i`/`f` を
  取り出す瞬間まで)評価を遅らせる」という意味です。`JNumber` は
  この型の唯一のコンストラクタではない(`JValue` には他の構築子もある)ため、
  本来はパターンマッチが失敗する可能性がありますが、「`jIntFrac` が返すのは
  必ず `JNumber` である」ことが分かっているので、`~` を付けて警告を承知の上で
  安全に決め打ちしています。

4つとも `src/Exercise/Part1/Parser.hs` に実装してください。

## jNumber: すべてを束ねる

```haskell
jNumber :: Parser String JValue
jNumber = jIntFracExp <|> jIntExp <|> jIntFrac <|> jInt
```

**順番が重要**です。最も「具体的」(条件が多い)ものから先に試し、
最後に最も「一般的」(条件が少ない)ものを試します。もし `jInt` を
先頭に置いてしまうと、`"1.5"` を読むときに `jInt` が `1` の部分だけを
読んで「成功」してしまい、`.5` が余った入力として残ってしまいます
(`jValue`/`parseJSON` で最終的に「入力が全部消費されたか」をチェックする
までエラーに気づけません)。

## 動作確認

```
ghci> import Exercise.Part1.Parser
ghci> runParser jNumber "01"
Just ("1",JNumber 0 [] 0)
ghci> runParser jNumber "44.3e-7"
Just ("",JNumber 44 [3] (-7))
```

`"01"` が `"1"` を余らせて `0` だけをパースする点(先頭ゼロの次は数値として
続かない)を確認してください。

```bash
cabal test part1
```

`prop_genParseJString` と `prop_genParseJNumber` が通れば OK です。

## 次へ

[09. jArray と jObject](09-jarray-and-jobject.md) に進んでください。
