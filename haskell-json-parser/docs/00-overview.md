# 00. 進め方と環境確認

## このブートキャンプで学ぶこと

「JSON パーサを書く」ことそのものは目的の半分でしかありません。本当のゴールは、
JSON パーサという具体的で手頃な題材を通して、次の2つを腹落ちさせることです。

1. **パーサコンビネータ**という考え方 ―― 小さいパーサを組み合わせて大きいパーサを作る
2. `Functor` / `Applicative` / `Monad` / `Alternative` という型クラスが、
   「なぜ存在するのか」「何が嬉しいのか」を、実際に自分で instance を書きながら体感する

これらの型クラスは Haskell のあらゆるライブラリ(`Maybe`, `[]`, `IO`, パーサライブラリ、
`Either` …)で使われる共通言語です。一度ここで手を動かして理解すると、他のライブラリの
ドキュメントを読むときの解像度が大きく変わります。

## 全体の流れ

```
Part1: バックトラッキング版パーサ (docs/03〜11)
  Parser 型の定義
    → Functor instance (digit のリファクタで必要になる)
    → Applicative instance (string のリファクタで必要になる)
    → Alternative instance (jBool の「true か false か」で必要になる)
    → Monad instance (jString のサロゲートペア処理で必要になる)
  jNull, jBool, jString, jNumber, jArray, jObject
    → jValue, parseJSON

Part2: エラーハンドリング版パーサ (docs/12〜24)
  なぜ Part1 では不十分か
    → ParseResult 型、Parser1 型(backtracking はまだ残っている中間形態)
    → バックトラッキングだとエラーメッセージが壊れる問題を実演
    → Zipper という考え方(まず ListZipper で足慣らし)
    → TextZipper(2次元テキストの中でカーソル位置を追跡)
    → 最終版 Parser 型 (TextZipper + ParseResult)
    → 位置情報つきエラーメッセージ
    → jNull, jBool, jString, jNumber, jArray, jObject を「先読み」方式で書き直す
    → jValue, parseJSON (Either 版)
```

Part2 では `Alternative` インスタンスを**あえて定義しません**。バックトラッキングを
やめて「先読み(lookahead)」に切り替えるからです。この理由は `docs/14` で詳しく扱います。

## 環境確認

このプロジェクトは `nix develop` で GHC 9.6.7 + cabal-install が
そろった開発シェルに入れるようにしてあります(`haskell-json-parser/flake.nix`)。
`nix` が使える環境なら、バージョンを個別にそろえる必要はありません。

```bash
cd haskell-json-parser
nix develop
```

シェルに入ったら(以降、明示していない限りこのシェルの中でコマンドを
実行してください)、ビルドが通ることを確認します。

```bash
cabal build
```

初回は `QuickCheck` と `split` パッケージのビルドが走るので少し時間がかかります。
ビルドが通ったら、模範解答が正しくテストを通過することを確認しておきましょう
(これが通らない場合は、あなたの実装ではなく環境の問題です)。

```bash
cabal test solutions-part1 solutions-part2
```

`+++ OK, passed 100 tests.` が Part1/Part2 それぞれ5個(`prop_genParseJString` から
`prop_genParseJSON` まで)、計10回表示されれば準備完了です。

`nix` を使わない場合は、`ghcup` などで GHC 9.6 系 + cabal-install を
別途そろえても構いません。

## GHCi での動作確認について

各ステップの解説には、ブログ記事にならって GHCi での実行例を載せています。
このプロジェクトでは(`nix develop` シェルの中で)`cabal repl` を実行して
GHCi を起動し、モジュールを import して試せます。

```bash
cabal repl lib:haskell-json-parser
```

```
ghci> import Exercise.Part1.Parser
ghci> runParser (char 'a') "abc"
```

まだ実装していない関数を呼ぶと `error "TODO: ..."` の例外が飛びますが、それは
「まだ実装していないだけ」で正常な反応です。慌てず、該当するステップに進んでください。

## 次へ

[01. JSON とパースの基礎](01-json-and-parsing.md) に進んでください。
