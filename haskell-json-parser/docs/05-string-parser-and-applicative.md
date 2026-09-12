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

> [!NOTE]
> <details>
> <summary><code>Just (rest, f) -&gt; fmap f &lt;$&gt; runParser po rest</code> でつまずきやすい3つのポイント</summary>
>
> ### 1. 構文: 演算子を中置で定義する
>
> `pf <*> po = ...`という形で**中置のまま**定義してください。
> `pf (<*>) po = ...`のように書くと、GHCは「`pf`という名前の関数を、
> `(<*>)`と`po`という2つの引数で定義しようとしている」と解釈してしまい、
> `Applicative`の`<*>`メソッドの実装として認識されません
> (`‘pf’ is not a (visible) method of class ‘Applicative’`というエラーに
> なります)。
>
> ### 2. `f <$> runParser po rest` では足りない(`fmap`を2回重ねる)
>
> `runParser po rest :: Maybe (i, a)`です。`f <$> runParser po rest`と
> 書くと、`Maybe`の`fmap`が`f`を**タプル`(i, a)`全体**に適用しようとして
> しまいます。しかし`f :: a -> b`はタプルではなく`a`だけを受け取る関数
> なので、型が合いません(`Couldn't match type ‘b’ with ‘(i, b)’`という
> エラーになります)。`digit3`のときと同じく、「`Maybe`の中の、タプルの
> 2番目」という2階層構造なので、`fmap`を**2回重ねる**必要があります。
>
> ```haskell
> Just (rest, f) -> fmap f <$> runParser po rest
> ```
>
> ここで2つの`<$>`/`fmap`は、それぞれ**別のFunctor**です。
>
> ```haskell
> ghci> :type runParser (char 'a') "abc"
> runParser (char 'a') "abc" :: Maybe (String, Char)
> ```
>
> - 外側の`<$>`(`fmap f <$> ...`の`<$>`) ―― `runParser po rest`が
>   `Maybe (i, a)`なので、**`Maybe`のFunctor**
> - 内側の`fmap f` ―― `(i, a) -> (i, b)`という変換なので、**タプルの
>   Functor**
> - `Parser`自身のFunctorは、この行の中では**一度も使われません**。
>   `runParser`で中身を取り出した時点で`Parser`という型はもう無く、
>   以降は`Maybe`とタプルという標準ライブラリの型だけを扱っています。
>   `Parser`のFunctorが使われるのは、`Parser $ ...`で包み終えた
>   **後**、他のコードがこの`Parser`の値に対して`fmap`/`<$>`を
>   呼んだときだけです。
>
> ### 3. `fmap f <$> runParser po rest` は `fmap (fmap f) . runParser po rest` ではない
>
> `.`(関数合成)は**2つの関数**を繋げるためのものです。
>
> ```haskell
> (.) :: (b -> c) -> (a -> b) -> a -> c
> ```
>
> `runParser po`(引数無し)は`i -> Maybe (i, a)`という**関数**なので
> `.`で繋げられますが、`runParser po rest`は**すでに`rest`まで渡して
> 実行済みの値**(`Maybe (i, a)`)です。関数ではなく値なので`.`の右側には
> 置けません(`‘runParser’ is applied to too many arguments`という
> エラーになります)。正しくは`$`か、何もつけない普通の関数適用です。
>
> ```haskell
> fmap (fmap f) $ runParser po rest
> -- または
> fmap (fmap f) (runParser po rest)
> ```
>
> `fmap f <$> runParser po rest`は、この`fmap (fmap f) (runParser po rest)`
> と完全に同じ意味です(`<$>`は中置の`fmap`なので)。
>
> </details>

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

> [!NOTE]
> **`Applicative` の「意味」と、`Parser` での「実装の仕方」を混同しないこと**
>
> `pf <*> po = Parser $ \i -> case runParser pf i of ...`という実装を見ると、
> 「`Applicative`とは、複数の関数を繋げて1つの関数を作ることだ」と思って
> しまいがちです。しかしこれは**`Parser`の中身がたまたま関数だったから、
> 実装がそういう形になっただけ**で、`Applicative`という概念自体の意味では
> ありません。
>
> `Applicative`の普遍的な意味は、**「複数引数の関数を、箱に入った引数に
> 1つずつ適用していく」**ことです。`f`が`Maybe`だろうが`[]`だろうが
> `Parser`だろうが、この「型の当てはめ方」は完全に共通です。
>
> ```haskell
> ghci> (+) <$> Just 3 <*> Just 5
> Just 8
> ghci> (,,) <$> [1,2] <*> ['a','b'] <*> [True,False]
> [(1,'a',True),(1,'a',False),(1,'b',True),(1,'b',False),(2,'a',True),(2,'a',False),(2,'b',True),(2,'b',False)]
> ```
>
> `Maybe`の`<*>`(`Just f <*> Just x = Just (f x)`)は単純なパターンマッチ
> だけで、「関数を繋げる」という話は一切出てきません。リストの`<*>`(全部の
> 組み合わせを作る)も同様です。「関数を繋げる」というのは、`Parser`の中身が
> 関数だったからこそ必要になった、**`Parser`固有の実装の都合**です。
>
> | | |
> |---|---|
> | `Applicative`という**概念**(型クラス) | 複数引数の関数を、箱に入った引数に1つずつ適用する(どの型でも共通) |
> | `Parser`における`<*>`の**実装** | たまたま中身が関数だったので、「2つの関数を繋げて新しい関数を作る」という手段になった |
>
> ### 「入力を読み進める」という性質も、同じく`Parser`固有
>
> `char c <*> char d`のように`<*>`を繋げていくと、「1つ目が消費した
> **残りの入力**を2つ目に渡す」ため、結果的に入力を前へ前へと読み進める
> ことになります。
>
> ```haskell
> ghci> runParser (char 'a') "abcde"
> Just ("bcde",'a')
> ghci> runParser ((,) <$> char 'a' <*> char 'b') "abcde"
> Just ("cde",('a','b'))
> ghci> runParser ((,,) <$> char 'a' <*> char 'b' <*> char 'c') "abcde"
> Just ("de",('a','b','c'))
> ```
>
> これも`Applicative`という型クラス自体が保証している性質ではありません。
> `pf <*> po`の実装で`runParser po rest`(`rest` = `pf`が消費した後の
> 残り)と書いたから、たまたまそうなっただけです。「効果」の中身は型ごとに
> 全く違います。
>
> | `f` | `<*>`の「効果」の中身 |
> |---|---|
> | `Maybe` | 失敗の伝播(`Nothing`ならそれ以上進まない) |
> | `[]` | 全組み合わせ(直積)を作る |
> | `Parser` | **入力を、前のパーサが消費した続きから読む** |
> | `IO` | 実世界で1つ目のアクションを実行してから2つ目を実行する |
>
> `Maybe`や`[]`には「入力」「残り」という概念自体がそもそも存在しません。
> `Applicative`は「2つの効果を順番に組み合わせられる」という**抽象的な
> 骨組み**だけを提供していて、「効果」が具体的に何を意味するかは、その型
> ごとに(今回で言えば`Parser`を設計した`docs`側が)決めるものです。

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
