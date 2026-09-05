package lisp

// STEP 4: 特殊形式 (special forms) を実装しましょう。
//
// 特殊形式とは、"if" や "define" のように、引数を先に評価してから渡すのではなく、
// 独自の評価ルールを持つ構文のことです（普通の関数呼び出しとは異なり、
// evalList の中で名前を見て特別扱いされます）。

// evalIf は (if 条件 then [else]) を評価します。
//
// 手順:
//  1. 引数の数が3個 (else省略) でも4個 (else あり) でもなければエラー。
//  2. list[1] (条件) を評価する。
//  3. IsTruthy(条件の結果) が真なら list[2] (then) を評価して返す。
//  4. 偽で、else (list[3]) があればそれを評価して返す。
//  5. 偽で、else が省略されていれば空リスト List{} を返す。
func evalIf(list List, env *Env) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: evalIf を実装してください")
}

// evalDefine は2つの構文をサポートします。
//   - (define 名前 値)                  ... 変数を定義する
//   - (define (名前 引数...) 本体...)    ... 関数を定義する糖衣構文
//
// 手順:
//  1. list の長さが3未満ならエラー。
//  2. list[1] の型で分岐する（Goの型スイッチが便利です）。
//     - Symbol の場合: list[2] を評価し、その結果を env.Define(名前, 値) する。
//     - List の場合  : target[0] を関数名、target[1:] を引数名のリストとして取り出し、
//     &Lambda{Params: ..., Body: list[2:], Env: env} を作って
//     env.Define(関数名, そのLambda) する。
//     引数名や関数名がSymbolでなければエラーにする。
//     - それ以外     : エラー。
//  3. 戻り値は定義した名前 (Symbol) を返す（REPLで見やすくするためです）。
func evalDefine(list List, env *Env) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: evalDefine を実装してください")
}

// evalSet は (set! 名前 値) を評価し、既存の変数の値を書き換えます。
//
// 手順:
//  1. list の長さが3でなければエラー。
//  2. list[1] が Symbol でなければエラー。
//  3. list[2] を評価する。
//  4. env.Set(名前, 評価結果) を呼ぶ（未定義ならエラーが返るので、そのまま返す）。
//  5. 成功したら評価結果を返す。
func evalSet(list List, env *Env) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: evalSet を実装してください")
}

// evalLambda は (lambda (引数...) 本体...) を評価し、クロージャ（*Lambda）を作ります。
// 現在の環境 env をそのままクロージャに閉じ込めることで、レキシカルスコープを実現します。
//
// 手順:
//  1. list の長さが3未満ならエラー。
//  2. list[1] が List でなければエラー（引数リストの形式）。
//  3. その中の各要素が Symbol であることを確認しながら、[]Symbol に変換する。
//  4. &Lambda{Params: 引数名のスライス, Body: list[2:], Env: env} を返す。
func evalLambda(list List, env *Env) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: evalLambda を実装してください")
}

// evalLet は (let ((名前 値)...) 本体...) を評価します。
// 束縛される値はすべて「外側の環境」で評価してから、新しい子環境にまとめて定義します
// （束縛同士が互いを参照できない、という let の基本ルールです）。
//
// 手順:
//  1. list の長さが3未満ならエラー。
//  2. list[1] が List (束縛のリスト) でなければエラー。
//  3. NewEnv(env) で子環境 letEnv を作る。
//  4. 束縛リストの各要素 (名前 値) について:
//     - (Symbol Value) の2要素Listであることを確認する。
//     - 値の部分を外側の env で評価する（letEnv ではない点に注意）。
//     - letEnv.Define(名前, 評価結果) する。
//  5. evalBody(list[2:], letEnv) で本体を評価して返す。
func evalLet(list List, env *Env) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: evalLet を実装してください")
}

// evalAnd は (and 式...) を評価します。
// 式を順番に評価し、いずれかが偽（#f）を返した時点で Bool(false) を返します。
// すべて真だった場合は、最後に評価した式の値を返します。
// 式が1つもない場合は Bool(true) を返します。
func evalAnd(exprs []Value, env *Env) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: evalAnd を実装してください")
}

// evalOr は (or 式...) を評価します。
// 式を順番に評価し、いずれかが真を返した時点でその値を返します。
// すべて偽だった場合は Bool(false) を返します。
func evalOr(exprs []Value, env *Env) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: evalOr を実装してください")
}
