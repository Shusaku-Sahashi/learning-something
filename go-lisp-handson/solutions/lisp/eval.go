package lisp

import "fmt"

// Eval はS式を評価して結果の値を返します。
func Eval(expr Value, env *Env) (Value, error) {
	switch v := expr.(type) {
	case Symbol:
		val, ok := env.Get(v)
		if !ok {
			return nil, fmt.Errorf("未定義の変数です: %s", v)
		}
		return val, nil

	case List:
		return evalList(v, env)

	default:
		// Number, Bool, String, *Lambda, *Builtin はすべて「自己評価する」値です。
		return v, nil
	}
}

// evalList はリスト形式のS式を評価します。
// 先頭要素が特殊形式（quote, if, define, ...）であればそれぞれの評価ルールに従い、
// そうでなければ「先頭を関数として、残りを引数として評価して呼び出す」関数適用として扱います。
func evalList(list List, env *Env) (Value, error) {
	if len(list) == 0 {
		return list, nil // 空リスト '() はそれ自身を表す
	}

	if sym, ok := list[0].(Symbol); ok {
		switch sym {
		case "quote":
			if len(list) != 2 {
				return nil, fmt.Errorf("quote は引数を1つだけ取ります")
			}
			return list[1], nil

		case "if":
			return evalIf(list, env)

		case "define":
			return evalDefine(list, env)

		case "set!":
			return evalSet(list, env)

		case "lambda":
			return evalLambda(list, env)

		case "let":
			return evalLet(list, env)

		case "begin":
			return evalBody(list[1:], env)

		case "and":
			return evalAnd(list[1:], env)

		case "or":
			return evalOr(list[1:], env)
		}
	}

	// 特殊形式でなければ、関数呼び出しとして扱う。
	fn, err := Eval(list[0], env)
	if err != nil {
		return nil, err
	}

	args := make([]Value, len(list)-1)
	for i, a := range list[1:] {
		val, err := Eval(a, env)
		if err != nil {
			return nil, err
		}
		args[i] = val
	}

	return Apply(fn, args)
}

// evalBody は複数の式を順番に評価し、最後の式の評価結果を返します。
// `begin` / `lambda` の本体 / `let` の本体で共通して使われます。
func evalBody(body []Value, env *Env) (Value, error) {
	if len(body) == 0 {
		return List{}, nil
	}
	var result Value
	var err error
	for _, expr := range body {
		result, err = Eval(expr, env)
		if err != nil {
			return nil, err
		}
	}
	return result, nil
}
