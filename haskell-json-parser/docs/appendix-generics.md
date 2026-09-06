# Appendix. GHC.Generics と `deriving (Generic)` 入門

このAppendixは、本編のどこかで一度読めば十分な独立した解説です。
`docs/02-json-data-type.md` からリンクされています。`JValue` の
`deriving (Eq, Generic)` の `Generic` が何をしているのか、なぜ
`genericShrink`(QuickCheck の Appendix で説明したもの)がこれだけで
動くのかを理解することを目指します。手を動かして実装する対象ではなく、
読み物として仕組みを掴むためのものです。

## 1. 何が問題なのか

`JValue` のようなデータ型に対して、QuickCheck の `shrink`(失敗した反例を
単純化する関数、`appendix-quickcheck.md` の6節を参照)を自分で書くとしたら、
こうなります。

```haskell
shrink :: JValue -> [JValue]
shrink JNull        = []
shrink (JBool _)     = []
shrink (JString s)   = JString <$> shrink s
shrink (JNumber i f e) =
  [JNumber i' f e | i' <- shrink i] ++
  [JNumber i f' e | f' <- shrink f] ++
  [JNumber i f e' | e' <- shrink e]
shrink (JArray xs)   = JArray <$> shrink xs
shrink (JObject kvs) = JObject <$> shrink kvs
```

構築子が増えるたびに似たようなケースを増やす必要があり、フィールドが
増えるたびに「このフィールドだけ単純化したバージョン」を列挙する
ボイラープレートが増えていきます。他の型でも同じパターンの繰り返しに
なりがちです。

`Generic` を `derive` すると、この手のボイラープレートを型ごとに
手で書かなくても、**型の「形」(構築子がいくつあるか、各構築子が
どんなフィールドを持つか)から自動的に導出**できるようになります。
`genericShrink` はまさにこれを行う関数です。

## 2. Generic とは何をする型クラスか

```haskell
class Generic a where
  type Rep a :: * -> *
  from :: a -> Rep a x
  to   :: Rep a x -> a
```

`Generic a` のインスタンスは、`a` 型の値を「構築子名やフィールドの
区別が付いたまま、より基本的な部品(タプルや `Either` に近いもの)に
変換する(`from`)」「その部品から元の `a` に戻す(`to`)」という
2つの関数を提供します。`Rep a` が、その「基本的な部品」としての表現の型です。

大事なのは、**あなたが手で `Generic` のインスタンスを書くことはまず
ありません**。`deriving (Generic)` と書くだけで GHC がコンパイル時に
自動生成します。私たちが理解すべきは「`Rep a` がどんな形をしているか」
という部分だけです。

## 3. Rep の中身: 小さい型で見てみる

`JValue` はいきなり見るには複雑なので、まず小さい型で考えます。

```haskell
{-# LANGUAGE DeriveGeneric #-}
import GHC.Generics

data Shape = Circle Double | Rectangle Double Double
  deriving (Generic, Show)
```

`Shape` の `Rep`(4節で実際に GHCi に表示させて確認します)は、
本質だけ取り出すとこういう形をしています。

```haskell
Rep Shape ~ (K1 R Double) :+: (K1 R Double :*: K1 R Double)
```

- `:+:` は**直和**(OR)を表します。「`Circle` の場合 **または**
  `Rectangle` の場合」という、構築子の選択に対応します。
  (`Either` の一般化版だと思ってください)
- `:*:` は**直積**(AND)を表します。「1つ目のフィールド **かつ**
  2つ目のフィールド」という、1つの構築子が複数フィールドを持つ状況に
  対応します。(タプルの一般化版だと思ってください)
- `K1 R Double` は「実際のフィールドの値(ここでは `Double`)」を
  保持する部分です。

つまり `Rep` は、**構築子の選択を `:+:` の入れ子で、フィールドの並びを
`:*:` の入れ子で表現した、型情報だけの「設計図」**です。`genericShrink`
のような関数は、具体的な型(`Shape` や `JValue`)を一切知らなくても、
この `:+:`/`:*:`/`K1` の組み合わせだけを見て「構築子ごとに分岐する」
「各フィールドを再帰的に処理する」という処理を書けます。これが
「型の形から自動導出する」ということの正体です。

実際の `Rep` にはこれ以外に `M1` というラッパーもあちこちに挟まりますが、
これは「型名・構築子名・フィールド名」といったメタデータ(文字列としての
名前)を一緒に運ぶためのものです。値の構造そのものには影響しません。

## 4. GHCi で実際に眺めてみる

`:kind!` を使うと、ある型の `Rep` が実際にどう展開されるか(かなり長く
なりますが)確認できます。

```
ghci> :set -XDeriveGeneric
ghci> import GHC.Generics
ghci> data Shape = Circle Double | Rectangle Double Double deriving (Generic, Show)
ghci> :kind! Rep Shape
Rep Shape :: * -> *
= M1
    D
    (MetaData "Shape" "Ghci1" "interactive" False)
    (M1
       C
       (MetaCons "Circle" PrefixI False)
       (M1
          S
          (MetaSel
             Nothing NoSourceUnpackedness NoSourceStrictness DecidedLazy)
          (K1 R Double))
     :+: M1
           C
           (MetaCons "Rectangle" PrefixI False)
           (M1
              S
              (MetaSel
                 Nothing NoSourceUnpackedness NoSourceStrictness DecidedLazy)
              (K1 R Double)
            :*: M1
                  S
                  (MetaSel
                     Nothing NoSourceUnpackedness NoSourceStrictness DecidedLazy)
                  (K1 R Double)))
```

見た目は圧倒されますが、3節で説明した通り読み解けます。`M1 D`(型全体の
メタデータ)の中に、`M1 C`(`Circle` 構築子)と `M1 C`(`Rectangle` 構築子)が
`:+:` で並び、`Rectangle` の中は2つの `M1 S`(フィールド)が `:*:` で
並んでいる ―― まさに「`Circle` の場合 **または** `Rectangle` の場合
(その中はフィールド1 **かつ** フィールド2)」という設計図そのものです。
(ドキュメントでは `M1 D f`/`M1 C f`/`M1 S f`/`K1 R a` の組み合わせに
それぞれ `D1 f`/`C1 f`/`S1 f`/`Rec0 a` という名前が付いていることもあります
―― これらは単なる型シノニムなので、`:kind!` はシノニムを展開した後の
`M1 ...`/`K1 R ...` の形で表示します。)

## 5. genericShrink はこれをどう使うか

`Test.QuickCheck.genericShrink :: (Generic a, ...) => a -> [a]` は、
おおまかに次のように動きます。

1. `from` で値を `Rep a` の形に変換する。
2. `:+:` で分岐している部分は、「今の構築子はそのままで中のフィールドを
   縮める」候補と「別の(より単純な)構築子に切り替える」候補の両方を
   列挙する。
3. `:*:` で並んでいる部分は、各フィールドを再帰的に `shrink` して、
   「1つのフィールドだけ単純化した」候補を列挙する。
4. 最後に `to` で `Rep a` の形から元の型 `a` に戻す。

これを型ごとに手で書く代わりに、`Generic` インスタンス(＝`Rep` という
設計図)さえあれば `genericShrink` という**1つの共通実装**で済ませられる
というのが `deriving (Generic)` のご利益です。`JValue` が
`deriving (Eq, Generic)` としているのは、まさにこの `genericShrink`
(`src/Json/Gen.hs` の `instance Arbitrary JValue` で使われています)を
タダで手に入れるためです。

## 6. QuickCheck 以外での使いどころ(参考)

`Generic` は QuickCheck 専用の仕組みではありません。同じ「型の形」を
利用して、JSON のシリアライズ/デシリアライズを自動導出する
[aeson](https://hackage.haskell.org/package/aeson) の
`deriving (Generic)` + `instance ToJSON/FromJSON` や、バイナリ
シリアライズを行う [binary](https://hackage.haskell.org/package/binary)
パッケージなど、Haskell のエコシステム全体で「型の構造から機械的に
導出できるものは手で書かない」という考え方の基盤になっています。
このプロジェクトでは QuickCheck の `genericShrink` としてしか
登場しませんが、「`deriving (Generic)` を見たら、何らかのライブラリが
型の構造を覗き見て処理を自動生成している」という読み方を覚えておくと、
他のライブラリのドキュメントを読むときにも役立ちます。

## 参考資料

- [GHC.Generics のドキュメント (Hackage)](https://hackage.haskell.org/package/base/docs/GHC-Generics.html)
- [QuickCheck の `genericShrink` (Hackage)](https://hackage.haskell.org/package/QuickCheck/docs/Test-QuickCheck.html#v:genericShrink)
