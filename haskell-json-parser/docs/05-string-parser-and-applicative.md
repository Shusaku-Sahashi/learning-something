# 05. 文字列パーサと Applicative

対応する実装ファイル: `src/Exercise/Part1/Parser.hs`(セクション `docs/05-...`)

## string1: 素朴な再帰実装

与えられた文字列全体が入力の先頭に一致するかを調べるパーサを書きます。

```haskell
string1 :: String -> Parser String String
```

再帰的に考えます。

- 探している文字列が空文字列 `""` なら、何も消費せず成功。入力全体と `""` を返す。
- 先頭が `c`、残りが `cs` の文字列 (`c:cs`) なら:
  1. `char c` で先頭1文字を消費できるか試す。失敗したら全体も失敗。
  2. 成功したら、残りの入力に対して再帰的に `string1 cs` を試す。失敗したら全体も失敗。
  3. 両方成功したら、`c` を先頭にくっつけた文字列を結果として返す。

```haskell
string1 :: String -> Parser String String
string1 s = case s of
  ""     -> Parser $ \i -> Just (i, "")
  (c:cs) -> Parser $ \i -> case runParser (char c) i of
    Nothing        -> Nothing
    Just (rest, _) -> case runParser (string1 cs) rest of
      Nothing         -> Nothing
      Just (rest', _) -> Just (rest', c:cs)
```

`src/Exercise/Part1/Parser.hs` に実装してください。動きますが、`Maybe` の
成功・失敗を毎回手でパターンマッチしているのがやはり冗長です。前のステップで
`Functor`(`fmap`)を導入して「中身を変換する」を簡潔にしたように、今度は
「2つのパーサを順番に実行し、両方成功したら結果を組み合わせる」という操作を
簡潔に書けるようにします。

## pure: 何も消費せず値を返すパーサ

まず、`string1 ""` のケースで書いた `Parser $ \i -> Just (i, "")` ―― 「入力を
まったく消費せず、決まった値を返すだけのパーサ」という概念に名前を付けます。

```haskell
pure :: a -> Parser i a
pure x = Parser $ pure . (, x)
```

ここで2つ、初見だと戸惑う書き方が出てきます。

- `(, x)` はタプルセクションです(`TupleSections` 拡張)。`(, x)` は
  `\y -> (y, x)` の省略記法で、「渡された値を1番目、`x` を2番目に入れたタプルを作る」
  関数になります。同様に `(x, )` なら `\y -> (x, y)` です。
- 右辺の `pure` は **`Maybe` に対する `pure`** です(`Parser` の `pure` を
  定義している最中に、別の型の `pure` を使っています)。`Maybe` にとっての
  `pure x` は `Just x` と同じです。`pure` は型クラス `Applicative` のメソッドで、
  型が違えば同じ名前でも別の実装が呼ばれます(`Maybe` の `pure` と `Parser` の
  `pure` は別物です)。

> [!NOTE]
> <details>
> <summary>右辺の <code>pure</code> がなぜ <code>Maybe</code> だとわかるのか(型推論の仕組み)</summary>
>
> `pure`は`Applicative`という型クラスのメソッドなので、単独では`Maybe`のものか
> 別の型のものか決まりません。実際に確認すると、式単独では型が確定していない
> ことが分かります。
>
> ```haskell
> ghci> :type pure . (, 'x')
> pure . (, 'x') :: Applicative f => a -> f (a, Char)
> ```
>
> `Applicative f =>`という**制約(まだ解決されていない型変数 `f`)**が残ったまま
> です。`Maybe`かもしれないし、`[]`かもしれないし、`IO`かもしれません。
>
> ところが `Parser $ ...` で包むと、この制約が消えて完全に具体的な型になります。
>
> ```haskell
> ghci> :type \x -> Parser $ pure . (, x)
> \x -> Parser $ pure . (, x) :: o -> Parser i o
> ```
>
> これは「`Parser`の定義そのものにヒントがある」からです。
>
> ```haskell
> newtype Parser i o = Parser { runParser :: i -> Maybe (i, o) }
> ```
>
> `Parser`という構築子(関数)の型は`Parser :: (i -> Maybe (i, o)) -> Parser i o`
> です。つまり`Parser $ 何か`と書いた瞬間、その「何か」は**必ず`i -> Maybe (i, o)`
> という型でなければならない**、とGHCは知っています(`Parser`の定義に`Maybe`
> という**具体的な型**が直接書かれているからです)。
>
> 型推論はここで「外側から内側へ」働きます。
>
> 1. `Parser $ (pure . (, x))` 全体の型は `i -> Maybe (i, o)` でなければならない
>    (`Parser` の定義より)
> 2. `pure . (, x) :: i -> f (i, x)`(`(, x)` の型と合成の型から)
> 3. 1と2を見比べると、`f (i, x)` は `Maybe (i, o)` と一致しなければならない
> 4. `f = Maybe`、`x = o` という組み合わせしかこれを満たせない →
>    **`f` は `Maybe` だと確定する**
>
> つまり「`pure`がどの型のものか」を先に決めてから式を書いているのではなく、
> **周りの文脈(ここでは`Parser`の中身が`Maybe`だと定義されていること)から
> 逆算して、GHCが後から`Maybe`だと確定させている**、という順番です。もし
> `Parser`の定義が`Maybe`の代わりに`Either String`のような別の型を使っていたら、
> この`pure`は自動的に`Either String`の`pure`(`\x -> Right x`)に解決されて
> いたはずです。
>
> </details>

`pure . (, x)` は関数合成なので、`\i -> pure ((, x) i)` すなわち
`\i -> pure (i, x)` すなわち `\i -> Just (i, x)` と同じ意味になります。

## <*>: 2つのパーサの結果を組み合わせる

次に `string1` の「1文字パースして、成功したら残りを再帰的にパースして、
結果をくっつける」という処理を一般化します。「関数を返すパーサ」と「値を返す
パーサ」があるとき、両方を順番に実行して、前者の関数を後者の値に適用する
演算子 `<*>` を定義します。

```haskell
(<*>) :: Parser i (a -> b) -> Parser i a -> Parser i b
```

まずは `string1` を、この `<*>` がある前提で書き直したらどうなるか見てみます
(これはヒントです。実際に書くのは `<*>` そのものの実装です)。

```haskell
string2 :: String -> Parser String String
string2 s = case s of
  ""     -> Parser $ pure . (, "")
  (c:cs) -> Parser $ \i -> case runParser (char c) i of
    Nothing        -> Nothing
    Just (rest, c') -> fmap (c':) <$> runParser (string2 cs) rest
```

この `string2` はすでに `src/Exercise/Part1/Parser.hs` に実装済みです(参考として
読んでください)。ここでの本題は `instance Applicative (Parser i)` を実装することです。

> [!NOTE]
> <details>
> <summary><code>Just (rest, c') -> fmap (c' :) &lt;$&gt; runParser (string2 cs) rest</code> の <code>(c' :)</code> がなぜ必要か</summary>
>
> `(c' :)` は `(== c)` のときと同じ**セクション(部分適用)**です。ただし `:`
> は非対称な演算子なので、`(== c)` と違って**左右で意味が変わります**。
>
> `:`(cons演算子)の型は `(:) :: a -> [a] -> [a]`(先頭に要素を追加してリストを
> 作る)です。
>
> ```haskell
> 'a' : "bc"   -- "abc" (先頭に 'a' を追加)
> ```
>
> `(c' :)` は**左側の `c'` だけを固定した**セクションなので、
>
> ```haskell
> (c' :) = \xs -> c' : xs
> ```
>
> つまり「**渡されたリスト(文字列)の先頭に `c'` をくっつける関数**」になります。
> 実際に確認しました。
>
> ```haskell
> ghci> ('a' :) "bc"
> "abc"
> ghci> (:) 'a' "bc"
> "abc"
> ```
>
> ### `string2` の中でなぜこれが必要か
>
> `string2 (c:cs)` は、「`c` を1文字パースして、残りの `cs` を再帰的にパースする」
> という処理でした。
>
> 1. `char c` で1文字読む → `c'`(実際には `c` と同じ文字)が取れる
> 2. `string2 cs` で残りの部分文字列をパース → 結果として `String`(例: `"bc"`)
>    が取れる
> 3. でも欲しいのは `"bc"` ではなく、**`c'` を先頭にくっつけた `"abc"`**
>    (全体で一致した文字列)
>
> この「先頭にくっつける」処理が `(c' :)` です。それを `fmap (c' :)` で(`Maybe`
> の中の)**タプルの2番目の要素**(パース結果の文字列)にだけ適用し、さらに
> 外側の `<$>` で `Maybe` の中に届かせています(これは `fmap (fmap f)` と全く
> 同じパターンで、`fmap g <$> x` は `fmap (fmap g) x` と書いても同じです)。
>
> 実際に動かして確認しました。
>
> ```haskell
> ghci> runParser (string2 "abc") "abcdef"
> Just ("def","abc")
> ghci> runParser (string2 "abc") "xyz"
> Nothing
> ```
>
> `"abcdef"` から `"abc"` という3文字が正しく1つの文字列として組み立てられて
> いるのが分かります。もし `(c' :)` が無かったら、`c'`(1文字目)と `string2 cs`
> の結果(残りの文字列)がバラバラのまま、正しく1つの文字列に組み立てられません。
>
> </details>

```haskell
instance Applicative (Parser i) where
  pure x    = ???
  pf <*> po = ???
```

- `pure` は前のセクションで説明した通りです。
- `pf <*> po` の実装方針:
  1. `pf`(関数を返すパーサ)を入力に対して実行する。
  2. 失敗したら全体も失敗。
  3. 成功したら、得られた関数 `f` と残りの入力を使って、`po` を実行する。
  4. `po` の結果(タプルの2番目、つまり値の部分)に `f` を適用する
     ―― これは `fmap f` で書けます。

`pf <*> po = Parser $ \input -> case runParser pf input of ...` という骨格で
書き始めるとよいでしょう。`Functor` のときと同様、「`Maybe` の中の、タプルの
2番目」に処理を施すパターンがまた出てきます。

実装できたら `string` を `<$>` と `<*>` を使って書き直します。

```haskell
string :: String -> Parser String String
string ""     = pure ""
string (c:cs) = (:) <$> char c <*> string cs
```

`(:) <$> char c <*> string cs` を型で追いかけると:

```
(:)              :: Char -> String -> String
char c           :: Parser String Char
(:) <$> char c   :: Parser String (String -> String)
string cs        :: Parser String String
(:) <$> char c <*> string cs :: Parser String String
```

「`char c` の結果(1文字)を先頭にくっつける関数」を `<$>` で作り、
`<*>` でその関数を「残りの文字列をパースした結果」に適用しています。
再帰・`Maybe`・タプルの分解を一切書かずに、`string1` と同じことをやっていることに
注目してください。これが `Applicative` の力です。

## Applicative とは結局何なのか

```haskell
class Functor f => Applicative f where
  pure  :: a -> f a
  (<*>) :: f (a -> b) -> f a -> f b
```

`Functor` は「1つの箱の中身を変換する」でした。`Applicative` はそれに加えて
「複数の箱を組み合わせる」ことができます。`pure` で値を箱に入れ、`<*>` で
「関数の箱」と「値の箱」を組み合わせて「結果の箱」を作ります。今回の `Parser`
で言えば、「複数のパーサを順番に実行して、それぞれの結果を1つにまとめる」
ことができるようになった、ということです。

`Applicative` は `Functor` の**上位互換**です(`class Functor f => Applicative f`
という制約からも分かる通り、`Applicative` であるためにはまず `Functor` である
必要があります)。`<$>` だけでは「1つの箱」しか扱えませんが、`<*>` を使えば
いくつでも箱をつなげられます。`(:) <$> char c <*> string cs` のように、
`<*>` は好きなだけ繋げて書けます(`f <$> a <*> b <*> c <*> ...`)。

## 動作確認

```
ghci> import Exercise.Part1.Parser
ghci> runParser (string "hello") "hello world"
Just (" world","hello")
ghci> runParser (string "hello") "help world"
Nothing
```

## 次へ

[06. jNull と Alternative](06-jnull-and-alternative.md) に進んでください。
