# 🌲 Go で作るミニLisp処理系ハンズオン

Go の標準ライブラリだけを使って、簡易的な Lisp インタプリタを **自分の手で実装しながら** 理解するハンズオンです。
完成済みのコードを読むのではなく、`internal/lisp/` 以下にある `TODO` コメント付きの関数を1つずつ自分で埋めていき、
テストを green にしていく形式で進めます。

## 📖 このハンズオンについて

- **対象読者**: Go の基本文法（構造体・インターフェース・スライス・マップ・型スイッチ・エラーハンドリング）が
  ひととおりわかる方。Lisp や関数型言語の知識は不要です。
- **完成すると**: 四則演算・変数定義・条件分岐・クロージャ・再帰関数が動く簡易 Lisp が出来上がり、
  対話的な REPL (Read-Eval-Print Loop) で実際に動かせるようになります。
- **かかる時間の目安**: 2〜4時間程度（Goに慣れている場合）。

```text
lisp> (define (fact n) (if (= n 0) 1 (* n (fact (- n 1)))))
fact
lisp> (fact 10)
3628800
lisp> (define add5 (let ((n 5)) (lambda (x) (+ x n))))
add5
lisp> (add5 37)
42
```

最終的にはこのように動くものを、自分の実装で作ります。

## 🧠 前提知識: Lisp / S式とは

Lisp は 1958年に John McCarthy が開発したプログラミング言語で、最大の特徴は **プログラムそのものが
「S式 (S-expression)」という1種類のデータ構造で表現される** ことです。

```lisp
(+ 1 2)          ; 1 + 2 と同じ意味。演算子を先頭に書く「前置記法」
(* 2 (+ 1 2))    ; 2 * (1 + 2) = 6。丸括弧で入れ子にするだけで式が組み立てられる
(define x 10)    ; 変数定義もリスト
(if (> x 5) "big" "small") ; 制御構文もリスト
```

見てのとおり、Lisp のプログラムは「丸括弧で囲まれた、空白区切りの要素の並び」がひたすら入れ子になった
ものです。この単純さゆえに、パーサーも評価器も比較的小さく実装できます。これが「Lisp処理系の自作」が
インタプリタ実装の学習教材として昔からよく使われている理由です。

このハンズオンで実装する処理の流れは次の3段階です。

```text
"(+ 1 2)"  --Tokenize-->  ["(", "+", "1", "2", ")"]  --Parse-->  List{Symbol("+"), Number(1), Number(2)}  --Eval-->  Number(3)
   文字列          トークン列                              S式(構文木)                              評価結果
```

## 🗺️ 全体構成と進め方

```text
go-lisp-handson/
├── go.mod
├── README.md               ← このファイル
├── internal/lisp/          👈 ここを実装していきます
│   ├── types.go             値の型定義 (実装済み・変更不要)
│   ├── token.go             STEP 1: Tokenize
│   ├── reader.go             STEP 2: Parse / readExpr / readList / parseAtom
│   ├── env.go                 STEP 3: Env (変数のスコープ)
│   ├── eval.go                 STEP 3: Eval / evalList / evalBody
│   ├── apply.go                STEP 3: Apply
│   ├── specialforms.go         STEP 4: if / define / set! / lambda / let / and / or
│   ├── builtins.go             STEP 5: +, -, car, cdr, display などの組み込み関数
│   └── *_test.go               各STEPに対応するテスト (編集不要)
├── cmd/repl/main.go         STEP 6: 対話的に動かすREPL (実装済み・変更不要)
├── examples/*.lisp          動作確認用のサンプルLispプログラム
└── solutions/                各STEPの完成形（詰まったときの参照用。中身は internal/lisp と同じ構成）
```

進め方はどのステップも共通です。

1. 対象のファイルを開き、関数の doc コメントに書かれた仕様とヒントを読む。
2. `panic("TODO: ...")` になっている関数の中身を実装する。
3. そのステップに対応するテストだけを絞り込んで実行し、green になるまで直す
   （コマンドは各STEPに記載しています）。
4. わからなくなったら `solutions/lisp/` 内の同名ファイルを覗いて答え合わせする。

> [!TIP]
> なぜ `go test ./...` を毎回使わず、`-run` でテストを絞り込むのか
> このハンズオンでは、未実装の関数は `panic("TODO: ...")` を呼ぶようにしてあります。
> Goのテストはpanicを検知すると **そのテストバイナリ全体を異常終了させる** ため、
> 後のステップ用のテスト（まだ手を付けていない関数を使うテスト）が先に実行されると、
> 今取り組んでいるステップの結果を確認する前に全体がクラッシュしてしまいます。
> それを避けるため、各ステップでは `-run` オプションで対象のテスト関数だけを実行します。

セットアップ確認として、まず以下を実行してみてください（`types.go` は最初から実装済みなので green になります）。

```bash
cd go-lisp-handson
go test ./internal/lisp/ -run 'TestIsTruthy|TestEqual|TestValueString' -v
```

## 🪜 STEP 1: トークナイザ（字句解析器）— `token.go`

### やること
`Tokenize(src string) ([]string, error)` を実装します。ソースコードの文字列を、
`"("` `")"` `"'"` と「アトム」（シンボル・数値・文字列リテラル）のトークン列に分割する関数です。

```text
Tokenize("(+ 1 2)") -> ["(", "+", "1", "2", ")"]
```

### 考え方
- 文字列を `[]rune` にして、先頭からインデックス `i` で1文字ずつ読み進めます。
- 空白はスキップ（区切りとしてのみ機能し、トークンにはならない）。
- `;` から行末までは1行コメントとして無視します。
- `"` から次の `"` までを1つの文字列トークンとして切り出します（ダブルクォート自体も含める）。
- それ以外の文字が連続する範囲を1つのアトムとして切り出します。

コード内の doc コメント（`internal/lisp/token.go`）に、より詳細な手順とヒント（使うと良い標準パッケージなど）
を書いてあるので、まずはそちらを読んでください。

### テストで確認する

```bash
go test ./internal/lisp/ -run 'TestTokenize' -v
```

コメントの扱い・文字列リテラルの扱い・quote省略記法 `'` の分割・閉じられていない文字列のエラーまで
テストされています。すべて green になったら次のステップへ進みます。

## 🪜 STEP 2: 構文解析器（パーサー / Reader）— `reader.go`

### やること
トークン列を、入れ子になった S式（`Value` の木構造）に組み立てます。実装するのは次の3関数です。

- `readExpr(tokens []string) (Value, []string, error)` — 先頭のトークンから1つのS式を読み取り、
  「読み取った値」と「残りのトークン列」を返す
- `readList(tokens []string) (Value, []string, error)` — `"("` を消費した状態から呼ばれ、対応する `")"`
  までを読み取って `List` にまとめる
- `parseAtom(tok string) Value` — 1トークンを `Number` / `Bool` / `String` / `Symbol` に変換する

`Parse` 関数自体（トップレベルのループ）はすでに実装済みです。まずそれを読んで、`readExpr` がどう
呼ばれているかを把握してから取りかかると進めやすいです。

### 考え方
`readExpr` は先頭のトークンで分岐する再帰下降パーサーです。

- 先頭が `"("` → `readList` に委ねる
- 先頭が `")"` → エラー（対応する `"("` がない）
- 先頭が `"'"` → 続きを再帰的に読んで `List{Symbol("quote"), 読んだ式}` にする（`'x` は `(quote x)` の糖衣構文）
- それ以外 → `parseAtom` で値に変換する

`parseAtom` では、`"#t"`/`"#f"` を真偽値に、ダブルクォートで囲まれた文字列を `String` に、
`strconv.ParseFloat` が成功する文字列を `Number` に、それ以外を変数名や関数名を表す `Symbol` に変換します。

### テストで確認する

```bash
go test ./internal/lisp/ -run 'TestParse' -v
```

ネストしたリスト、quote省略記法、括弧の対応が壊れている場合のエラーまで確認しています。

## 🪜 STEP 3: 値の環境と評価器の骨格 — `env.go` / `eval.go` / `apply.go`

いよいよ「評価する」部分、インタプリタの心臓部です。3つのファイルにまたがりますが、互いに強く
関係しているので1つのステップとしてまとめて進めます。

### 3-1. `Env`（変数のスコープ）— `env.go`

`Env` は「変数名 → 値」のマップに加えて、親環境へのポインタを持つ構造体です（すでに定義済み）。
親をたどれるようにすることで、後述する「クロージャ」（関数が定義された時点の環境を覚えている関数）が
実現できます。実装するのは3つのメソッドです。

- `Get(sym Symbol) (Value, bool)` — 現在の環境になければ親へ、さらにその親へ…とたどって探す
- `Define(sym Symbol, val Value)` — 現在の環境にだけ変数を定義する（親はたどらない）
- `Set(sym Symbol, val Value) error` — **すでにある**変数の値を書き換える。`Get` と似ているが、
  「見つけたら書き換える」という点で異なる。見つからなければエラーを返す

### 3-2. `Eval` / `evalList` / `evalBody` — `eval.go`

- `Eval(expr Value, env *Env) (Value, error)` は、`expr` の **Goの型** によって処理を振り分ける、
  評価器全体の入り口です。`Symbol` なら環境から検索、`List` なら `evalList` に委譲、それ以外
  （`Number` / `Bool` / `String` / `*Lambda` / `*Builtin`）は「自己評価する値」としてそのまま返します。
- `evalList` は、リストの先頭が特殊形式（`quote` など）であれば専用の評価ルールに従い、
  そうでなければ「先頭を関数として評価し、残りを引数として評価して呼び出す」という通常の関数呼び出し
  として扱います。**このステップでは `quote` 以外の特殊形式（`if` や `define` など）はまだ実装しません**
  （STEP 4 で追加します）。呼び出し先の分岐だけ書いておいて、あとから STEP 4 で肉付けする形になります。
- `evalBody` は複数の式を順番に評価し、最後の式の結果を返す補助関数です。`begin` や関数本体の評価で
  共通して使われます。

### 3-3. `Apply` — `apply.go`

`Apply(fn Value, args []Value) (Value, error)` は関数呼び出しの実行部分です。

- `fn` が `*Builtin`（Goの関数で実装された組み込み関数）なら、そのままGo関数を呼びます。
- `fn` が `*Lambda`（ユーザー定義関数）なら、パラメータ名と引数の値を対応づけた新しい環境を作り、
  関数本体を評価します。**ここで新しい環境の親を「呼び出した場所の環境」ではなく「関数が定義された
  時点の環境 (`f.Env`)」にする** のが、クロージャが正しく動くための最大のポイントです。

### テストで確認する

STEP 3 の時点では `if` や `define`、`lambda` はまだ特殊形式として実装されていないので、テストでは
あらかじめ `env.Define` で登録しておいた `*Builtin` を使って、シンボル解決・`quote`・関数呼び出しの
仕組みだけを確認します。

```bash
go test ./internal/lisp/ -run 'TestEnv|TestEval' -v
```

## 🪜 STEP 4: 特殊形式 — `specialforms.go`

`if` や `define` のように、引数を先にすべて評価してしまうと成り立たない構文（例えば `if` は
選ばれなかった枝を評価してはいけません）を「特殊形式」と呼びます。`evalList`（STEP 3で実装済み）が
すでに `"if"` や `"define"` などのシンボル名で分岐して、これから実装する関数を呼び出す作りに
なっています。実装するのは次の7関数です。

| 関数 | 構文 | 意味 |
| --- | --- | --- |
| `evalIf` | `(if 条件 then [else])` | 条件が真なら then、偽なら else を評価する |
| `evalDefine` | `(define 名前 値)` / `(define (名前 引数...) 本体...)` | 変数 or 関数を定義する |
| `evalSet` | `(set! 名前 値)` | 既存の変数の値を書き換える |
| `evalLambda` | `(lambda (引数...) 本体...)` | クロージャ (`*Lambda`) を作る |
| `evalLet` | `(let ((名前 値)...) 本体...)` | ローカル変数を束縛して本体を評価する |
| `evalAnd` | `(and 式...)` | 短絡評価の論理積 |
| `evalOr` | `(or 式...)` | 短絡評価の論理和 |

`evalDefine` には2つの構文があることに注意してください。`(define (square x) (* x x))` は
`(define square (lambda (x) (* x x)))` の糖衣構文です。`list[1]` が `Symbol` か `List` かで
Goの型スイッチを使って分岐すると綺麗に書けます。

`evalLambda` で作った `*Lambda` に、現在の環境 `env` をそのまま持たせる（`Env: env`）ことで、
後から `Apply`（STEP 3で実装済み）がそれを親環境として使い、クロージャが変数を「覚えている」ように
振る舞います。

### テストで確認する

```bash
go test ./internal/lisp/ -run 'TestIf|TestDefine|TestLambdaAndClosure|TestSetBang|TestLet|TestBegin|TestAndOr' -v
```

`TestLambdaAndClosure` では、関数が返した別の関数（クロージャ）が、外側の関数のローカル変数を
正しく覚えていることを確認しています。ここが green になれば、レキシカルスコープが正しく実装できて
いる証拠です。

## 🪜 STEP 5: 組み込み関数 — `builtins.go`

ここまでで「言語のコア」（特殊形式）は完成しています。STEP 5 では、`+` や `car` のような、
Go関数として実装する組み込み関数を実装します。`NewGlobalEnv()`（登録処理そのもの）は実装済みなので、
そこから呼ばれている各関数の中身を埋めていってください。

- 算術演算: `builtinSub` (`-`), `builtinDiv` (`/`), `builtinMod` (`mod`)、比較演算をまとめて作る
  `numCompare`（`=` `<` `>` `<=` `>=` の元になる「関数を返す関数」）、引数を検証しつつ `[]float64` に
  変換する `toNumbers`
  （`+` と `*` は畳み込み処理の共通部分 `numFold` として実装済みです）
- リスト操作: `builtinCons` / `builtinCar` / `builtinCdr` / `builtinNullP` / `builtinListP` /
  `builtinLength` / `builtinAppend` / `builtinList`、および `car`/`cdr` の共通チェックである
  `requireNonEmptyList`
- その他: `builtinNot`、構造的な等価性を見る `builtinEqualP`（`types.go` の `Equal` 関数を使います）、
  出力用の `builtinDisplay` / `displayString` / `builtinNewline`

1つ1つは短い関数なので、`internal/lisp/builtins.go` の doc コメントを見ながら、上から順に埋めていく
とスムーズです。`mod` の実装だけ `math` パッケージ（`math.Mod`）のインポートが必要な点に注意してください。

### テストで確認する

```bash
go test ./internal/lisp/ -run 'TestArithmetic|TestComparisons|TestListOps|TestRecursive' -v
```

`TestRecursiveFactorial` / `TestRecursiveFibonacci` は、`define` で自分自身を呼び出す再帰関数が
実際に動くかどうかの統合テストです。ここまでのすべての実装が噛み合って初めて green になります。

### 最終チェック

すべてのステップが終わったら、パッケージ全体のテストを実行してすべて green であることを確認します。

```bash
go test ./internal/lisp/... -v
```

## 🪜 STEP 6: REPLで実際に動かす — `cmd/repl/main.go`

`cmd/repl/main.go` は実装済みです（変更不要）。引数なしで実行すると対話的なREPLに、ファイルパスを
渡すとそのファイルをスクリプトとして実行します。中身は「1行ずつ読み → 括弧の数を数えて式が完結したら
`Parse` → `Eval` → 結果を表示」という、これまでに作った関数を組み合わせているだけのプログラムです。
時間があれば軽く読んでみてください。

```bash
# 対話的に試す
go run ./cmd/repl

# サンプルプログラムを実行する
go run ./cmd/repl examples/factorial.lisp
go run ./cmd/repl examples/fibonacci.lisp
go run ./cmd/repl examples/list-ops.lisp
```

`examples/` には次のサンプルがあります。

- `factorial.lisp` — 再帰による階乗計算
- `fibonacci.lisp` — 再帰によるフィボナッチ数列
- `list-ops.lisp` — `let` + `lambda` + `set!` によるクロージャ（カウンタ）と、`map` 相当の自作関数

すべて実装し終えたあとにこれらが動けば、ハンズオンは完了です 🎉

## 🧩 詰まったときは

`solutions/` ディレクトリに、`internal/lisp/` と同じ構成で完成版の実装を置いてあります
（`solutions/lisp/*.go`、REPLは `solutions/cmd/repl/main.go`）。まずは自分で試行錯誤し、
どうしても分からない箇所だけ該当ファイルを覗いて答え合わせをする、という使い方を推奨します。

```bash
go test ./solutions/lisp/... -v   # 完成版はすべてのテストが通ることを確認できます
```

## 🚀 次の一歩（発展課題）

一通り動くようになった後、さらに理解を深めたい場合は次のような拡張に挑戦してみてください。

- **末尾呼び出し最適化 (TCO)**: 現在の `Apply`/`Eval` は再帰のたびにGoのスタックを消費するため、
  深い再帰（例えば `(fact 100000)` のような末尾再帰）でスタックオーバーフローします。
  `evalList` をループに書き換えて、末尾位置の呼び出しを「新しい式で `Eval` をやり直す」ループに
  変換してみましょう。
- **エラーメッセージの改善**: 現在はどこで構文エラーが起きたか（行番号・列番号）を教えてくれません。
  `Tokenize` でトークンごとに位置情報を持たせて、エラーメッセージに含めてみましょう。
- **`cond` や `case` の追加**: `if` の連鎖を読みやすく書くための特殊形式を追加してみましょう。
- **`quasiquote` / `unquote`**: `` ` `` `,` を実装すると、Lispらしい「コードをデータとして組み立てる」
  感覚が体験できます。
- **文字列操作関数**: `string-append`、`substring` などを `builtins.go` に追加してみましょう。
- **整数と浮動小数の区別**: 現在は数値をすべて `float64` (`Number`) として扱っています。
  Go の `int64` と `float64` を使い分ける「数値タワー」に挑戦すると、型変換の設計力が鍛えられます。

## 🛠️ このハンズオンで練習できるGoの要素

- インターフェース (`Value`) と、それを満たす複数の型（`Symbol` / `Number` / `Bool` / `String` / `List` /
  `*Lambda` / `*Builtin`）の設計
- 型スイッチ (`switch v := expr.(type)`) を使った分岐
- 再帰関数（`readExpr`/`readList`、`Eval`/`evalList`、`my-map` などのLisp側の再帰）
- クロージャ（Go自体の関数リテラルとしての `Builtin.Fn`、そしてLisp側の `*Lambda` が親環境を
  参照することで実現する言語機能としてのクロージャ、その両方が登場します）
- `error` 型を使ったエラーハンドリング（パニックではなく戻り値でエラーを伝搬する設計）
- テーブル駆動テスト (`internal/lisp/*_test.go`)
