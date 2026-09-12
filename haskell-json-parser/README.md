# Haskell JSON Parser 自作ブートキャンプ

[abhinavsarkar.net の "JSON Parsing from Scratch in Haskell"](https://abhinavsarkar.net/posts/json-parsing-from-scratch-in-haskell/)
シリーズ(全3記事)をベースに、JSON パーサをゼロから自分の手で実装しながら、
Haskell の `Functor` / `Applicative` / `Monad` / `Alternative` と、パーサコンビネータの
考え方を身につけるための教材です。

## 対象読者

- Haskell の基本的な構文(パターンマッチ、型クラス、`data` 宣言など)は読み書きできる。
- `Functor` / `Applicative` は「なんとなく `<$>` や `<*>` を使ったことがある」くらいで、
  仕組みは朧げにしか理解していない。
- `Data.Char` や `Control.Applicative` などの標準ライブラリ関数は、都度調べないと分からない。

上記に当てはまる人向けに、各ステップで「なぜその型クラスが必要になるのか」「使っている
標準ライブラリ関数が何をするのか」を、実装に入る前に丁寧に解説します。

## 全体構成

2つのパートに分かれています。

- **Part1(`docs/03`〜`docs/11`)**: バックトラッキング方式のシンプルな JSON パーサ。
  失敗したら `Nothing` を返すだけで、どこで何が起きたかは分かりません。
  `Functor` → `Applicative` → `Alternative` → `Monad` の順に、必要になったタイミングで
  1つずつ学びながら実装します。
- **Part2(`docs/12`〜`docs/24`)**: Part1 の弱点(エラーメッセージがない)を解消するために、
  パーサ全体を書き直します。`Zipper` というデータ構造でカーソル位置を追跡し、
  「何行目・何列目で、何を期待していたのに何が来たか」を報告できるようにします。

Part2 は Part1 の上に積み増すのではなく、まったく別のパーサとして最初から書き直します
(ブログの原文もそういう構成です)。理由は `docs/12-why-error-handling.md` で説明します。

## ディレクトリ構成

```
haskell-json-parser/
├── docs/                       -- このブートキャンプ本体(ステップごとの解説)
├── src/
│   ├── Json/Value.hs           -- あなたが実装するファイル: JValue 型 と Show インスタンス
│   ├── Json/Gen.hs             -- 与えられたコード: QuickCheck 用ジェネレータ
│   ├── Exercise/Part1/Parser.hs -- あなたが実装するファイル (Part1)
│   ├── Exercise/Part2/Parser.hs -- あなたが実装するファイル (Part2)
│   └── Exercise/Appendix/Gen.hs -- あなたが実装するファイル (Appendix, 任意)
├── test/
│   ├── Part1Spec.hs            -- Exercise.Part1.Parser を検証するテスト
│   ├── Part2Spec.hs            -- Exercise.Part2.Parser を検証するテスト
│   ├── AppendixGenSpec.hs      -- Exercise.Appendix.Gen を検証するテスト (任意)
│   ├── SolutionsPart1Spec.hs   -- 模範解答が正しく通ることを確認するテスト
│   └── SolutionsPart2Spec.hs   -- 同上 (Part2)
└── solutions/
    ├── Solutions/Part1.hs      -- Part1 の模範解答(ブログのサンプルコードそのまま)
    └── Solutions/Part2.hs      -- Part2 の模範解答(ブログのサンプルコードそのまま)
```

`src/Json/Value.hs` は JValue 型(構築子は与えられています)と、それを
JSON テキストとして表示する `Show` インスタンスを実装するファイルです
(`docs/02-json-data-type.md`)。JSON をどう「書き出す」かは JSON の構造
そのものの理解に直結するので、ここも手を動かします。

`src/Json/Gen.hs`(QuickCheck 用のランダム値生成)は引き続き「与えられている
コード」です。中身を読む必要はありますが、自分で実装する対象ではありません。
読み飛ばして先に進んでも大丈夫です(気になったら `docs/02-json-data-type.md`
で概要を、`docs/appendix-quickcheck.md` で詳細を解説します。同じものを
自分の手で実装してみる腕試しも Appendix に用意してあります)。

## 進め方

1. `docs/00-overview.md` から順番に読む。
2. 各ドキュメントの指示に従って `src/Exercise/PartN/Parser.hs` の該当する
   `error "TODO: ..."` を実装で置き換える。
3. 実装できたら対応するテストを実行して確認する。

```bash
cabal test part1   # Part1 の実装を検証
cabal test part2   # Part2 の実装を検証
cabal test appendix-gen   # (任意) Appendix の Gen.hs 実装を検証
```

テストは QuickCheck によるプロパティベーステストです。ランダムな JSON 値を
100 個生成し、それぞれ「値 → テキスト化 → パース」した結果が元の値と一致するかを
確認します。まだ実装していない関数(`error "TODO: ..."`)を呼び出すと、
どのファイルの何行目で止まっているかが例外メッセージに出るので、それを頼りに
次に実装すべき箇所が分かります。

詰まってどうしても分からないときは `solutions/Solutions/PartN.hs` を見てください。
見る前に一度は自分の力で書いてみることを強くお勧めします(パーサコンビネータも
型クラスも、手を動かして初めて body で理解できるようになります)。

## セットアップ (nix)

このディレクトリには `flake.nix` が用意されており、`nix develop` で
GHC 9.6.7 + cabal-install が入った開発シェルに入れます。バージョンを
個別にインストールする必要はありません。

```bash
cd haskell-json-parser
nix develop          # GHC 9.6.7 / cabal-install が使えるシェルに入る
```

以降のコマンド(`cabal build`, `cabal test ...` など)は、この
`nix develop` シェルの中で実行してください。毎回シェルに入るのが
面倒な場合は `nix develop --command <コマンド>` の形でも実行できます。

```bash
nix develop --command cabal build          # 依存パッケージ(QuickCheck, split)を取得してビルド
nix develop --command cabal test solutions-part1 solutions-part2   # 模範解答が通ることを確認 (任意)
```

nix を使わない場合は、`ghcup` などで GHC 9.6 系 + cabal-install を
別途そろえても構いません(`flake.nix` の内容は無視されます)。

GHCi で対話的に試したいときは:

```bash
nix develop --command cabal repl lib:haskell-json-parser
```

```
ghci> import Exercise.Part1.Parser
ghci> runParser jNull "null"
```

## 各ステップの一覧

| # | ファイル | 内容 |
|---|---|---|
| 00 | [overview](docs/00-overview.md) | 進め方、環境確認 |
| 01 | [json-and-parsing](docs/01-json-and-parsing.md) | JSON 文法の要点、パーサコンビネータとは |
| 02 | [json-data-type](docs/02-json-data-type.md) | `JValue` 型と `Show` インスタンスを読む |
| 03 | [parser-type-and-char-parser](docs/03-parser-type-and-char-parser.md) | `Parser` 型、`char1`/`satisfy`/`char` |
| 04 | [digit-parser-and-functor](docs/04-digit-parser-and-functor.md) | `digit1`〜`digit3`、`Functor` |
| 05 | [string-parser-and-applicative](docs/05-string-parser-and-applicative.md) | `string1`/`string2`、`Applicative` |
| 06 | [jnull-and-alternative](docs/06-jnull-and-alternative.md) | `jNull`、`Alternative` |
| 07 | [jstring-and-monad](docs/07-jstring-and-monad.md) | Unicode サロゲート、`Monad`、`jString` |
| 08 | [jnumber](docs/08-jnumber.md) | JSON 数値パーサ一式 |
| 09 | [jarray-and-jobject](docs/09-jarray-and-jobject.md) | `jArray`、`jObject` |
| 10 | [jvalue-and-parsejson](docs/10-jvalue-and-parsejson.md) | `jValue`、`parseJSON`、全体テスト |
| 11 | [part1-wrapup](docs/11-part1-wrapup.md) | Part1 振り返りと Part2 への橋渡し |
| 12 | [why-error-handling](docs/12-why-error-handling.md) | Part1 の弱点、目指すゴール |
| 13 | [parseresult-and-parser1](docs/13-parseresult-and-parser1.md) | `ParseResult`、`Parser1` |
| 14 | [backtracking-problem](docs/14-backtracking-problem.md) | バックトラッキングの罠、先読み |
| 15 | [zippers](docs/15-zippers.md) | `Zipper` の考え方(`ListZipper`) |
| 16 | [text-zipper](docs/16-text-zipper.md) | `TextZipper`、位置の追跡 |
| 17 | [zippered-parser](docs/17-zippered-parser.md) | 最終版 `Parser` 型 |
| 18 | [errors-with-position](docs/18-errors-with-position.md) | 位置情報付きエラーメッセージ |
| 19 | [basic-parsers-rewrite](docs/19-basic-parsers-rewrite.md) | `lookahead`/`satisfy`/`char`/`jNull`/`jBool` |
| 20 | [jstring-rewrite](docs/20-jstring-rewrite.md) | エラー報告付き `jString` |
| 21 | [jnumber-rewrite](docs/21-jnumber-rewrite.md) | エラー報告付き `jNumber` |
| 22 | [jarray-jobject-rewrite](docs/22-jarray-jobject-rewrite.md) | エラー報告付き `jArray`/`jObject` |
| 23 | [jvalue-and-final](docs/23-jvalue-and-final.md) | `jValue`、`parseJSON`、最終テスト |
| 24 | [conclusion](docs/24-conclusion.md) | 振り返りと発展課題 |
| Appendix | [QuickCheck 入門](docs/appendix-quickcheck.md) | `Gen`/`Arbitrary`/`shrink` の詳細、自分でPBTを書く練習 |
| Appendix | [GHC.Generics 入門](docs/appendix-generics.md) | `deriving (Generic)` の仕組み、`genericShrink` が動く理由 |
| Appendix | [GHCi デバッグ入門](docs/appendix-ghci-debugging.md) | `:type`/`::`/`:info`/`:browse`/`:kind` の使い分け |

## 参考資料

- [JSON Parsing from Scratch in Haskell](https://abhinavsarkar.net/posts/json-parsing-from-scratch-in-haskell/)
- [JSON Parsing from Scratch in Haskell: Error Reporting—Part 1](https://abhinavsarkar.net/posts/json-parsing-from-scratch-in-haskell-2/)
- [JSON Parsing from Scratch in Haskell: Error Reporting—Part 2](https://abhinavsarkar.net/posts/json-parsing-from-scratch-in-haskell-3/)
- [RFC 8259 (JSON)](https://www.rfc-editor.org/rfc/rfc8259)
