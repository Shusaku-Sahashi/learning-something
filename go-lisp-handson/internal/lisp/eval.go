package lisp

// STEP 3: 評価器の中心 Eval を実装しましょう。
//
// Eval はS式を評価して結果の値を返します。exprの型によって処理を分けます
// （Goの型スイッチ `switch v := expr.(type) { ... }` を使うとよいでしょう）。
//
//   - Symbol の場合          : env から値を探して返す。見つからなければエラー。
//   - List の場合            : evalList に処理を委ねる。
//   - それ以外 (Number, Bool, String, *Lambda, *Builtin)
//     : 「自己評価する値」なのでそのまま返す。
func Eval(expr Value, env *Env) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: Eval を実装してください")
}

// evalList はリスト形式のS式を評価します。
// 先頭要素が特殊形式（quote, if, define, ...）であればそれぞれの評価ルールに従い、
// そうでなければ「先頭を関数として、残りを引数として評価して呼び出す」関数適用として扱います。
//
// 手順:
//  1. list が空リストなら、それ自身 (list) を返す（'() は自己評価する）。
//  2. list[0] が Symbol で、かつ以下のいずれかに一致するなら、対応する関数を呼ぶ:
//     "quote" -> list[1] をそのまま返す（評価しない。引数は1つだけのはず）
//     "if"    -> evalIf(list, env)
//     "define"-> evalDefine(list, env)
//     "set!"  -> evalSet(list, env)
//     "lambda"-> evalLambda(list, env)
//     "let"   -> evalLet(list, env)
//     "begin" -> evalBody(list[1:], env)
//     "and"   -> evalAnd(list[1:], env)
//     "or"    -> evalOr(list[1:], env)
//  3. どれにも一致しなければ、関数呼び出しとして扱う。
//     list[0] を Eval して関数を得て、list[1:] の各要素を Eval して引数を作り、
//     Apply(fn, args) を呼ぶ。
//
// STEP 4 (specialforms.go) までは quote 以外の特殊形式は実装されていないので、
// このステップでは quote と関数呼び出しだけ動けば十分です。
func evalList(list List, env *Env) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: evalList を実装してください")
}

// evalBody は複数の式を順番に評価し、最後の式の評価結果を返します。
// `begin` / `lambda` の本体 / `let` の本体で共通して使われます。
// body が空の場合は空リスト List{} を返してください。
func evalBody(body []Value, env *Env) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: evalBody を実装してください")
}
