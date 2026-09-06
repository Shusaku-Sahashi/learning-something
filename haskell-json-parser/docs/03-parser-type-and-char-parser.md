# 03. Parser 型と文字パーサ

対応する実装ファイル: `src/Exercise/Part1/Parser.hs`(セクション `docs/03-...`)

## パーサを「型」として定義する

パーサとは何かを、型で表現するところから始めます。パーサは「入力を受け取り、
できるところまで読み進めて、(残りの入力, 読み取った結果) を返す。読めなければ
失敗する」ものでした。これをそのまま関数の型にすると:

```haskell
i -> Maybe (i, o)
```

`i` が入力の型(今回は基本的に `String`)、`o` が読み取った結果の型です。
成功したら `Just (残りの入力, 結果)`、失敗したら `Nothing` を返します。

この関数を `newtype` でラップして名前を付けます(すでに `src/Exercise/Part1/Parser.hs`
に書かれています)。

```haskell
newtype Parser i o =
  Parser { runParser :: i -> Maybe (i, o) }
```

`newtype` は「1つのフィールドを持つ `data`」とほぼ同じですが、実行時のオーバーヘッドが
ないという特徴があります。`Parser` は「パーサの値」を表す型、
`runParser :: Parser i o -> i -> Maybe (i, o)` は「パーサに実際に入力を渡して実行する」
関数です。この「型を作って、実行する関数を分ける」パターンは、これから何度も
出てきます。

> [!NOTE] **`newtype` の定義の仕方・使い方**
>
> `newtype` は「既存の型に**新しい名前(＝新しい型)を付けて包む**」ための宣言です。
> 中身は既存の型と同じ(実行時には包んだ分のコストが無い)なのに、型としては
> **別物として扱われる**のがポイントです。
>
> ### 定義の仕方
>
> ```haskell
> newtype 型名 引数 = 構築子名 { アクセサ名 :: 中身の型 }
> ```
>
> 今回の例で言えば:
>
> ```haskell
> newtype Parser i o = Parser { runParser :: i -> Maybe (i, o) }
> --      ^型名 ^引数   ^構築子名  ^アクセサ名   ^包んでいる中身の型
> ```
>
> これで一度に2つのものが手に入ります。
>
> 1. **`Parser`** という型名(`Parser i o` のように2つの型引数を取る)
> 2. **`Parser`** という構築子(値を作るための関数。型名と同じ名前を
>    付けるのが Haskell では一般的です)
> 3. **`runParser`** というアクセサ関数(中身を取り出す関数。レコード構文
>    `{ フィールド名 :: 型 }` を使うと自動的に生成されます)
>
> ### 値を作る(構築子を使う)
>
> 構築子はただの関数なので、包みたい値(ここでは `i -> Maybe (i, o)` 型の関数)を
> 渡すだけで `Parser` の値が作れます。
>
> ```haskell
> myParser :: Parser String Char
> myParser = Parser (\i -> case i of
>   (x:xs) -> Just (xs, x)
>   []     -> Nothing)
> ```
>
> ### 中身を取り出す(2通りの方法)
>
> **方法1: アクセサ関数を使う**(レコード構文で定義したので自動的に使えます)
>
> ```haskell
> ghci> runParser myParser "abc"
> Just ("bc",'a')
> ```
>
> <details>
> <summary><code>runParser myParser "abc"</code> は本当は何をしているのか(2段階の関数適用)</summary>
>
> `runParser` の型は `runParser :: Parser i o -> i -> Maybe (i, o)` です。矢印`->`が
> 2つありますが、Haskell の関数は常にカリー化されているので、これは
> `runParser :: Parser i o -> (i -> Maybe (i, o))` と同じ意味です。つまり
> **`runParser` は `Parser i o` 型の値を1つだけ受け取る関数**で、`myParser` に
> `runParser` という名前で定義されている(＝格納されている)関数を返します。
>
> 関数適用は左結合なので、`runParser myParser "abc"` は
> `(runParser myParser) "abc"` と同じです。2段階に分けて考えます。
>
> 1. **`runParser myParser`**: `myParser` に `runParser` という名前で
>    定義されている関数(`\case (x:xs) -> Just (xs, x); [] -> Nothing`)を
>    取得する。この時点ではまだ `"abc"` は登場していません。
> 2. **`(1の結果) "abc"`**: 1で取得した関数に `"abc"` を渡して実行する。
>    `(x:xs)` パターンに `x = 'a'`, `xs = "bc"` とマッチし、
>    `Just ("bc", 'a')` が返る。
>
> ここで大事なのは、`"abc"` が渡される相手は **`runParser` という関数そのもの**
> ではなく、**`runParser myParser` という式の結果(＝`myParser` から取得された、
> あの `\case ...` という関数)** だという点です。`runParser` 自身は常に
> `Parser i o` 型の値を1つ受け取るだけで、2つ目の引数(`"abc"`)を直接
> 受け取っているわけではありません。
>
> </details>
>
> **方法2: パターンマッチで取り出す**(構築子名をパターンとして使う)
>
> ```haskell
> useIt :: Parser i o -> i -> Maybe (i, o)
> useIt (Parser f) input = f input
> ```
>
> どちらも同じ中身を取り出しているだけなので、結果は同じです。このプロジェクトの
> コードでは基本的に**方法1(アクセサ関数)**を使います。
>
> ### なぜ `type`(型シノニム)ではダメなのか
>
> 「`i -> Maybe (i, o)` にただ別名を付けたいだけなら `type Parser i o = i -> Maybe (i, o)`
> でいいのでは?」と思うかもしれません。しかし `type` は**本当にただの別名**で、
> 型としては元の型(`i -> Maybe (i, o)`、つまり関数そのもの)と完全に同一です。
>
> このプロジェクトでは、この後 `Parser i o` に**自分たちの**`Functor`/`Applicative`/
> `Monad`/`Alternative` インスタンスを定義していきます。もし `type` で別名を
> 付けただけなら、それは「関数の型」そのものに instance を定義することになり、
> 標準ライブラリがすでに提供している関数の `Functor` インスタンス(`fmap` が
> 関数合成になる、`(->) r` に対するもの)と衝突してしまいます。`newtype` で
> **型として区別**することで、`Parser i o` 専用の(パースという意味に沿った)
> `Functor`/`Applicative`/... インスタンスを、既存の関数の instance とは
> 別物として安全に定義できるのです。

## char1: 1文字だけを見るパーサ

最初のパーサを書きます。「与えられた1文字と、入力の先頭が一致するかどうか」を
チェックするパーサです。

```haskell
char1 :: Char -> Parser String Char
```

### 実装のヒント

- `Parser` の中身は関数なので、`Parser $ \i -> ...` のような形になります。
- 入力 `i :: String` の**先頭1文字**を見て、それが引数の文字 `c` と一致するかで
  分岐します。`String` は `[Char]` なので、`(x:xs)` というパターンで
  「先頭の文字 `x` と残り `xs`」に分解できます。
- 入力が空文字列 `""` だったり、先頭文字が `c` と違ったりしたら `Nothing`。
- 一致したら `Just (残りの入力, 消費した文字)` を返します。

このファイルでは `{-# LANGUAGE LambdaCase #-}` 拡張が有効になっています。
`\case` は `\i -> case i of` の省略記法です。例えば:

```haskell
f = \case
  (x:xs) | x == 'a' -> ...
  _                 -> ...
```

は

```haskell
f = \i -> case i of
  (x:xs) | x == 'a' -> ...
  _                 -> ...
```

と同じ意味です(引数を明示的に書かなくてよくなる)。どちらの書き方でも構いません。

`src/Exercise/Part1/Parser.hs` の `char1` を実装してください。

## satisfy: 述語を受け取る汎用版

`char1` は「特定の1文字と一致するか」しか判定できません。もっと汎用的に、
「先頭の要素が何らかの条件(述語関数)を満たすか」を判定できるパーサを書きます。

```haskell
satisfy :: (a -> Bool) -> Parser [a] a
```

`String` ではなく `[a]` を受け取る型になっている点に注目してください。文字列に
限らず、任意のリストに対して使える汎用的なパーサになっています。

やることは `char1` とほぼ同じで、「`x == c`」の部分が「`predicate x`」になるだけです。
実装したら、`char1` は実質 `satisfy` の特殊ケースだと気づけるはずです。実際、
そのことを使って `char` を書き直します。

```haskell
char :: Char -> Parser String Char
char c = satisfy (== c)
```

これは既に実装されています(`(== c)` は「`c` と等しいかを判定するセクション」)。
`satisfy` さえ実装できれば `char` はタダで手に入ります。これが「小さい部品を
組み合わせて大きい部品を作る」というパーサコンビネータの最初の実例です。

## 動作確認

`satisfy` と `char1` を実装したら、GHCi で試してみましょう。

```bash
cabal repl lib:haskell-json-parser
```

```
ghci> import Exercise.Part1.Parser
ghci> runParser (char1 'a') "abhinav"
Just ("bhinav",'a')
ghci> runParser (char1 'a') "sarkar"
Nothing
ghci> runParser (char 'x') "xyz"
Just ("yz",'x')
```

## 次へ

[04. 数字パーサと Functor](04-digit-parser-and-functor.md) に進んでください。
