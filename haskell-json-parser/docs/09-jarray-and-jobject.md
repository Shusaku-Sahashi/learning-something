# 09. jArray と jObject

対応する実装ファイル: `src/Exercise/Part1/Parser.hs`(セクション `docs/09-...`)

新しい型クラスはもう出てきません。ここからは今まで手に入れた道具(`Functor`,
`Applicative`, `Alternative`, `Monad`)を使って、JSON の複合型を組み立てます。

## ヘルパー: surroundedBy, separatedBy, spaces

配列・オブジェクトどちらにも共通する「両端の記号を読み飛ばす」「区切り文字で
区切られた並びを読む」という処理を、先に部品として切り出します。

```haskell
surroundedBy ::
  Parser String a -> Parser String b -> Parser String a
surroundedBy p1 p2 = p2 *> p1 <* p2
```

`p1 \`surroundedBy\` p2` は「`p2`, `p1`, `p2` の順に読み、`p1` の結果だけを返す」
パーサです。`*>`/`<*` はどちらも `Applicative` の仲間で、「両方実行するが
どちらか片方の結果だけを採用する」という意味でした(`*>` は右側、`<*` は
左側の結果を採用)。実装してください(`p2 *> p1 <* p2` の1行で書けます)。

```haskell
separatedBy :: Parser i v -> Parser i s -> Parser i [v]
separatedBy v s =   (:) <$> v <*> many (s *> v)
                <|> pure []
```

`v \`separatedBy\` s` は「`s` で区切られた `v` の並び」を読みます。
`Control.Applicative.many :: Alternative f => f a -> f [a]` は `some` の
「0回以上」版です(1回も無ければ空リスト)。

- 1つ目の選択肢: 最初の `v` を読み、続けて `many (s *> v)`(「区切り文字+`v`」
  を0回以上)を読んで、リストにまとめる。
- 2つ目の選択肢: 1つ目が失敗したら(=最初の要素すらない)、空リストを返す。

実装してください。

```haskell
spaces :: Parser String String
spaces = many (char ' ' <|> char '\n' <|> char '\r' <|> char '\t')
```

JSON が許す4種類の空白文字を0回以上読みます。実装してください。

## jArray

```haskell
jArray :: Parser String JValue
jArray = JArray <$>
  (char '['
   *> (jValue `separatedBy` char ',' `surroundedBy` spaces)
   <* char ']')
```

`[` を読み、中身を「カンマ区切りの `jValue`」として読み、その前後の空白も
許容し(`surroundedBy spaces`)、最後に `]` を読みます。ここで
**`jValue` はまだこのファイルに定義されていません**。次のステップ (10) で
定義するものを先取りして使っています。Haskell では、モジュール内のトップ
レベルの定義はどの順番で書いても、お互いを参照できます(相互再帰)。
`jArray` を実装してください(`jValue` はまだ実装しなくて構いません。
コンパイルは通ります)。

## jObject

```haskell
jObject :: Parser String JValue
jObject = JObject <$>
  (char '{' *> pair `separatedBy` char ',' `surroundedBy` spaces <* char '}')
  where
    pair = (\ ~(JString s) j -> (s, j))
      <$> (jString `surroundedBy` spaces)
      <*  char ':'
      <*> jValue
```

`jArray` とほぼ同じ構造ですが、要素が `jValue` 単体ではなく
「キー: 値」のペア (`pair`) です。

- `jString \`surroundedBy\` spaces`: キー部分。前後の空白を許容した文字列。
- `<* char ':'`: コロンを読むが結果は捨てる。
- `<*> jValue`: 値部分。
- `\ ~(JString s) j -> (s, j)`: `jString` の結果は必ず `JString s` の形を
  しているとわかっているので(08 で見た `~` と同じ遅延パターン)、
  中の `String` を取り出してタプルにする。

`jObject` を実装してください。

## 動作確認

`jValue` がまだ無いので、`jArray`/`jObject` を直接 GHCi で試すことはまだ
できません(コンパイルエラーになるわけではなく、実行時に `error "TODO"` に
当たります)。この2つの実装が終わったら、次のステップですぐに動作確認します。

## 次へ

[10. jValue と parseJSON](10-jvalue-and-parsejson.md) に進んでください。
