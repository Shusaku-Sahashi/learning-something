# Appendix: GHCi デバッグ入門

`Functor`/`Applicative`/`Monad` を実装していく中で、「この`fmap`は結局どの
`Functor`のもの?」「この式、どんな型になるんだ?」と頭の中だけで悩む場面が
何度も出てきます。多くの場合、**頭の中で解決しようとせず、GHCiに聞いてしまう**
のが一番早くて確実です。このAppendixでは、本編の中で実際に使ったGHCiの
使い方をまとめます。

## `:type` ―― 評価せずに型だけを見る

```haskell
ghci> :type runParser (satisfy isDigit)
runParser (satisfy isDigit) :: String -> Maybe (String, Char)
```

`:type 式`は、式を**評価しない**まま型だけを教えてくれるGHCiのコマンドです
(`:`で始まるのはGHCi専用のコマンドという印で、`.hs`ファイルには書けません)。
副作用のある式(`IO`アクションなど)や、まだ実装が終わっていない
(`error "TODO: ..."`が呼ばれる)式でも、型さえ合っていれば安全に確認できます。

`fmap`を何重にも重ねた式など、「結局これは何型になるんだ?」と迷ったら、
即座に`:type`で確認する癖をつけてください。

```haskell
ghci> :type fmap (fmap digitToInt)
fmap (fmap digitToInt)
  :: (Functor f1, Functor f2) => f1 (f2 Char) -> f1 (f2 Int)
ghci> :type fmap (fmap digitToInt) . runParser (satisfy isDigit)
fmap (fmap digitToInt) . runParser (satisfy isDigit)
  :: String -> Maybe (String, Int)
```

単独では`(Functor f1, Functor f2) =>`という制約が残ったままの式でも、
具体的な型を持つ式と合成した瞬間に型が確定する、という様子がそのまま見えます。

## `expr :: 型` ―― 型注釈(GHCi専用ではない、本物のHaskell構文)

`:type`と混同しやすいですが、これは別物です。`::`は`.hs`ファイルにも書ける
**本物のHaskell構文**で、「この式の型はこれだ」と型チェッカーに伝えるための
**型注釈**です。式を評価しない`:type`とは違い、`expr :: 型`をそのまま実行すると
**実際に評価され、値が表示されます**。

```haskell
ghci> (empty :: Maybe Int)
Nothing
```

型クラスのメソッド(`pure`、`empty`、数値リテラルなど)は、単独では
「どの型のインスタンスか」が決まらず、評価すらできないことがあります。

```haskell
ghci> print empty

Ambiguous type variables ‘f0’, ‘a0’ arising from a use of ‘print’
...
Probable fix: use a type annotation to specify what ‘f0’, ‘a0’ should be.
```

エラーメッセージが言う通り、型注釈を付けて`f0`を確定させれば評価できるように
なります。

```haskell
ghci> print (empty :: Maybe Int)
Nothing
ghci> print (empty :: [Int])
[]
```

同じ`empty`でも、注釈した型によって別のインスタンス(`Maybe`の`empty`、
`[]`の`empty`)が選ばれ、結果も変わります。

> [!NOTE]
> 型注釈は「何にでも付けられる」わけではありません。付けられるのは
> **その式がすでに要求している制約(型クラスのインスタンスであること)を
> 満たしていて、カインドも合っている型**だけです。
>
> ```haskell
> ghci> print (1 :: String)
> No instance for ‘Num String’ arising from the literal ‘1’
> ```
>
> `1`は`Num a => a`という制約付きの式なので、`Num`のインスタンスが無い
> `String`を注釈するとエラーになります(`1 :: Double`なら`Double`に
> `Num`インスタンスがあるので通ります)。
>
> ```haskell
> ghci> print ("hello" :: Int)
> Couldn't match type ‘[Char]’ with ‘Int’
> ```
>
> `"hello"`はすでに`String`という具体的な型を持つ式なので、制約うんぬん以前に
> 「もう`String`だと決まっているのに`Int`と言われても矛盾している」という
> エラーになります。

## `:info` ―― 型クラス・型の定義とインスタンス一覧を見る

```haskell
ghci> :info Alternative
class Applicative f => Alternative f where
  empty :: f a
  (<|>) :: f a -> f a -> f a
  ...
instance Alternative IO
instance Alternative []
instance Alternative Maybe
```

型クラスのメソッド一覧や、どの型がそのクラスのインスタンスになっているかが
分かります。「`Maybe`は`Alternative`のインスタンスなんだっけ?」のような
確認に便利です。

`newtype`/`data`に対して使うと、構築子とフィールド名も確認できます。

```haskell
ghci> :info Parser
newtype Parser i o = Parser {runParser :: i -> Maybe (i, o)}
runParser :: Parser i o -> i -> Maybe (i, o)
```

## `:browse` ―― モジュールが実際に何をエクスポートしているか見る

`import Exercise.Part1.Parser`のように、エクスポートリストの無い
(`module M where`とだけ書かれた)モジュールをimportしたとき、「そのモジュールが
`Data.Char`などから取り込んで使っているだけの関数」は**再エクスポートされません**
(モジュール自身が定義したものだけがエクスポートされます)。

```haskell
ghci> :browse Exercise.Part1.Parser
```

これでそのモジュールが実際にエクスポートしている名前の一覧が見られます。
`isDigit`のような、モジュールが`Data.Char`から借りてきているだけの関数は
一覧に出てきません。GHCiで`isDigit`のような関数を直接試したいときは、

```haskell
ghci> import Exercise.Part1.Parser
ghci> import Data.Char (isDigit)
```

のように、必要なものは別途importする必要があります。

## `:kind` / `:kind!` ―― 型そのものの「型」を見る

```haskell
ghci> :kind Char
Char :: *
ghci> :kind (String -> String)
(String -> String) :: *
ghci> :kind Maybe
Maybe :: * -> *
```

`*`(`Type`とも書きます)は「具体的な1つの型」を表すカインドです。`Char`も
`String -> String`(関数の型)も同じ`*`なので、型システムから見れば対等に
扱われます(`Parser i o`の`o`に関数の型を入れても何の問題も無い、という話は
`docs/05`のNoteで扱った通りです)。

`Maybe`のように`* -> *`(型を1つ受け取ってようやく具体的な型になる)を持つ
ものだけが`Functor`/`Applicative`/`Monad`のインスタンスになれます。

### `:kind`で何が分かるか・何に使えるか

**1. その型が`Functor`/`Applicative`/`Monad`のインスタンスになれるかどうかを
判断できる**

`Functor f`の`f`は`* -> *`でなければいけない、というルールでした
(`docs/04`のNote参照)。`:kind`で確認すれば、頭の中で悩まずに判断できます。

```haskell
ghci> :kind Either
Either :: * -> * -> *
```

`Either`は`* -> * -> *`(型を2つ受け取ってようやく具体的な型になる)なので、
**このままでは**`Functor`のインスタンスにはなれません。1つだけ型を
部分適用してあげると、

```haskell
ghci> :kind (Either String)
(Either String) :: * -> *
```

`* -> *`になり、`Functor`のインスタンスになれる形になります(実際に
`Either String`は`Functor`のインスタンスで、`fmap`は`Right`側にだけ
作用します。`docs/04`で説明した「タプルの`Functor`は最後の型引数にしか
作用しない」というルールと同じ理屈です)。

**2. カインド不一致によるエラーを事前に予測できる**

以前 `empty :: Int` が `No instance for ...` ではなく
`Couldn't match expected type` というエラーになったのは、
`Int`のカインドが合っていなかったからでした。

```haskell
ghci> :kind Int
Int :: *
ghci> :kind Maybe
Maybe :: * -> *
```

`Alternative f`の`f`には`* -> *`の型しか入れられないので、`Int`(`*`)を
見た瞬間に「これは`Alternative`のインスタンスになりようがない」と
`:info`や実装を読む前に判断できます。

**3. 型コンストラクタを部分適用したときの結果を確認できる**

```haskell
ghci> :kind (,)
(,) :: * -> * -> *
ghci> :kind (,) String
(,) String :: * -> *
```

`digit3`の`fmap (fmap digitToInt)`を読み解く際に「内側のFunctorは
`(,) String`だ」と結論づけましたが、`:kind (,) String`が`* -> *`に
なることを確認すれば、「確かに`Functor`のインスタンスになれる形をしている」
と裏付けが取れます。

`:kind!`は型シノニムや型族を実際に展開して見せてくれます(`GHC.Generics`の
`Rep`のように、裏側で何段にも型シノニムが積み重なっているものを確認するのに
便利です。詳しくは[GHC.Generics 入門](appendix-generics.md)を参照してください)。

## 関数は `print` できない ―― `Just (rest, f)` の `f` を確かめるには

```haskell
ghci> print ((:) <$> char 'a')

No instance for ‘Show (Parser String (String -> String))’
```

`Applicative`の`<*>`を実装していると、`Just (rest, f)`の`f`のように
**結果が関数**になる場面が出てきます。関数は`Show`のインスタンスに
なれないので(無限に多くの入出力の組を文字列にはできない)、そのまま`print`
することはできません。中身を確かめたいときは、実際に何か引数を渡して
呼び出した結果を見ます。

```haskell
ghci> let Just (rest, f) = runParser ((:) <$> char 'a') "abc"
ghci> rest
"bc"
ghci> f "XX"
"aXX"
```

## まとめ: 迷ったらGHCiに聞く

| やりたいこと | コマンド |
|---|---|
| 評価せず型だけ知りたい | `:type 式` |
| 型クラスのメソッドをどのインスタンスとして評価するか確定させたい | `式 :: 型` |
| 型クラス/型の定義・インスタンス一覧を見たい | `:info 名前` |
| モジュールが実際に何をエクスポートしているか見たい | `:browse モジュール名` |
| 型のカインドを見たい / 型シノニムを展開したい | `:kind 型` / `:kind! 型` |
| 関数として返ってきた値の中身を確かめたい | 実際に引数を渡して呼び出す |

`fmap`を2重に重ねた式や、`pure`/`empty`のようにどのインスタンスか一見して
分からない式に出会ったら、暗算で解決しようとせず、このAppendixのコマンドで
1つずつ確認しながら読み進めてください。
