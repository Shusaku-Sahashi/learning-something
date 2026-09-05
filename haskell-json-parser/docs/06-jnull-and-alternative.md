# 06. jNull と Alternative

対応する実装ファイル: `src/Exercise/Part1/Parser.hs`(セクション `docs/06-...`)

## jNull: 最初の JSON パーサ

これまでに作った道具(`string`, `Functor`, `Applicative`)を使って、初めて JSON の
値に対応するパーサを書きます。JSON の `null` は文字列 `"null"` そのものです。

```haskell
jNull :: Parser String JValue
```

やることは「`string "null"` を実行し、成功したら結果を `JValue` の `JNull` に
差し替える」だけです。ここで使うと便利なのが `Data.Functor.($>)` です。

```haskell
($>) :: Functor f => f a -> b -> f b
```

`x $> y` は「`x` を実行はするが結果は捨てて、代わりに `y` を返す」という意味です
(`<$` の引数順を逆にしたもの、と覚えても構いません)。`fmap (const y) x` と同じです。
つまり:

```haskell
jNull = string "null" $> JNull
```

は「`string "null"` を実行して、成功したらその結果 (`"null"` という文字列) を
捨てて `JNull` を返す」という意味になります。`src/Exercise/Part1/Parser.hs` に
実装してください。

## jBool には「どちらか」が必要

次に真偽値のパーサです。JSON の真偽値は `"true"` か `"false"` のどちらかの文字列です。

```haskell
jBool :: Parser String JValue
```

「`string "true"` を試して、失敗したら `string "false"` を試す」という、
**選択(バックトラッキング)** の機能が必要です。しかしこれまで作った
`Functor`/`Applicative` には「失敗したら別の手段を試す」という概念がありません。
`Applicative` は「両方成功させて結果を組み合わせる」ための道具であって、
「どちらか一方だけ成功すればよい」には対応していません。

## Alternative: 失敗したら別のものを試す

そこで登場するのが `Alternative` という型クラスです。

```haskell
class Applicative f => Alternative f where
  empty :: f a
  (<|>) :: f a -> f a -> f a
```

- `empty` は「必ず失敗する」值です。`Maybe` で言えば `Nothing` に相当します。
- `p1 <|> p2` は「`p1` を試して、成功すればその結果を、失敗すれば `p2` を試した
  結果を返す」という意味です。`Maybe` で言えば
  `Nothing <|> y = y` / `Just x <|> _ = Just x` に相当します。

`Alternative` は `Applicative` の上位に位置する型クラスです
(`class Applicative f => Alternative f` という制約に注目)。`Applicative` が
「複数の処理を両方実行して組み合わせる」道具だったのに対し、`Alternative` は
「複数の処理のうちどれか1つが成功すればよい」道具です。パーサの世界では
この性質のことを**バックトラッキング**と呼びます。 ―― `p1` を試して失敗したら、
入力を最初の位置に戻して `p2` を試す、という動きになるからです。

`src/Exercise/Part1/Parser.hs` の `instance Alternative (Parser i)` を
実装してください。

- `empty`: どんな入力に対しても失敗する(`Nothing` を返す)パーサ。
- `p1 <|> p2`: `p1` を実行してみて、成功ならその結果を、失敗なら `p2` を
  同じ入力に対して実行した結果を返す。

**ヒント**: `Parser` の中身は結局 `i -> Maybe (i, o)` という関数です。
`Maybe` 自身にも `Alternative` インスタンスが標準ライブラリに用意されている
(`import Control.Applicative (Alternative(..))` で使える)ので、
「`Maybe` の `<|>` を、`Parser` を実行した結果に対して使う」という形で
実装できます。

実装できたら `jBool` を書きます。

```haskell
jBool :: Parser String JValue
jBool =   string "true"  $> JBool True
      <|> string "false" $> JBool False
```

## 動作確認

```
ghci> import Exercise.Part1.Parser
ghci> runParser jNull "null"
Just ("",JNull)
ghci> runParser jNull "dull"
Nothing
ghci> runParser jBool "true"
Just ("",JBool True)
ghci> runParser jBool "false"
Just ("",JBool False)
ghci> runParser jBool "truth"
Nothing
```

`"truth"` が `Nothing` になることを確認してください。`string "true"` の時点で
`"tru"` までは読めますが、残り `"th"` が `"e"` と一致しないため `string "true"`
全体が失敗し、`<|>` によって `string "false"` が試され、それも `'f'` の時点で
一致せず失敗するので、全体として `Nothing` になります。

## 次へ

[07. Unicode サロゲートと Monad](07-jstring-and-monad.md) に進んでください。
