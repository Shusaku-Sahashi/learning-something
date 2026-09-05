package lisp

import "fmt"

// evalIf は (if 条件 then [else]) を評価します。
// 条件が真（#f 以外）なら then を、そうでなければ else を評価します。
// else が省略されていて条件が偽の場合は、空リストを返します。
func evalIf(list List, env *Env) (Value, error) {
	if len(list) != 3 && len(list) != 4 {
		return nil, fmt.Errorf("if は (if 条件 then [else]) の形で書きます")
	}
	cond, err := Eval(list[1], env)
	if err != nil {
		return nil, err
	}
	if IsTruthy(cond) {
		return Eval(list[2], env)
	}
	if len(list) == 4 {
		return Eval(list[3], env)
	}
	return List{}, nil
}

// evalDefine は2つの構文をサポートします。
//   - (define 名前 値)                  ... 変数を定義する
//   - (define (名前 引数...) 本体...)    ... 関数を定義する糖衣構文
func evalDefine(list List, env *Env) (Value, error) {
	if len(list) < 3 {
		return nil, fmt.Errorf("define は (define 名前 値) または (define (名前 引数...) 本体...) の形で書きます")
	}

	switch target := list[1].(type) {
	case Symbol:
		val, err := Eval(list[2], env)
		if err != nil {
			return nil, err
		}
		env.Define(target, val)
		return target, nil

	case List:
		if len(target) == 0 {
			return nil, fmt.Errorf("define の関数名が空です")
		}
		name, ok := target[0].(Symbol)
		if !ok {
			return nil, fmt.Errorf("define の関数名はシンボルである必要があります")
		}
		params := make([]Symbol, len(target)-1)
		for i, p := range target[1:] {
			sym, ok := p.(Symbol)
			if !ok {
				return nil, fmt.Errorf("引数名はシンボルである必要があります")
			}
			params[i] = sym
		}
		lambda := &Lambda{Params: params, Body: list[2:], Env: env}
		env.Define(name, lambda)
		return name, nil

	default:
		return nil, fmt.Errorf("define の1つ目の引数がシンボルでも関数定義でもありません")
	}
}

// evalSet は (set! 名前 値) を評価し、既存の変数の値を書き換えます。
func evalSet(list List, env *Env) (Value, error) {
	if len(list) != 3 {
		return nil, fmt.Errorf("set! は (set! 名前 値) の形で書きます")
	}
	sym, ok := list[1].(Symbol)
	if !ok {
		return nil, fmt.Errorf("set! の1つ目の引数はシンボルである必要があります")
	}
	val, err := Eval(list[2], env)
	if err != nil {
		return nil, err
	}
	if err := env.Set(sym, val); err != nil {
		return nil, err
	}
	return val, nil
}

// evalLambda は (lambda (引数...) 本体...) を評価し、クロージャ（*Lambda）を作ります。
// 現在の環境 env をそのままクロージャに閉じ込めることで、レキシカルスコープを実現します。
func evalLambda(list List, env *Env) (Value, error) {
	if len(list) < 3 {
		return nil, fmt.Errorf("lambda は (lambda (引数...) 本体...) の形で書きます")
	}
	paramList, ok := list[1].(List)
	if !ok {
		return nil, fmt.Errorf("lambda の引数リストは (a b c) の形である必要があります")
	}
	params := make([]Symbol, len(paramList))
	for i, p := range paramList {
		sym, ok := p.(Symbol)
		if !ok {
			return nil, fmt.Errorf("引数名はシンボルである必要があります")
		}
		params[i] = sym
	}
	return &Lambda{Params: params, Body: list[2:], Env: env}, nil
}

// evalLet は (let ((名前 値)...) 本体...) を評価します。
// 束縛される値はすべて「外側の環境」で評価してから、新しい子環境にまとめて定義します
// （束縛同士が互いを参照できない、という let の基本ルールです）。
func evalLet(list List, env *Env) (Value, error) {
	if len(list) < 3 {
		return nil, fmt.Errorf("let は (let ((名前 値)...) 本体...) の形で書きます")
	}
	bindings, ok := list[1].(List)
	if !ok {
		return nil, fmt.Errorf("let の1つ目の引数は束縛のリストである必要があります")
	}

	letEnv := NewEnv(env)
	for _, b := range bindings {
		pair, ok := b.(List)
		if !ok || len(pair) != 2 {
			return nil, fmt.Errorf("let の束縛は (名前 値) の形である必要があります")
		}
		sym, ok := pair[0].(Symbol)
		if !ok {
			return nil, fmt.Errorf("let で束縛する名前はシンボルである必要があります")
		}
		val, err := Eval(pair[1], env) // 値は外側の環境で評価する
		if err != nil {
			return nil, err
		}
		letEnv.Define(sym, val)
	}

	return evalBody(list[2:], letEnv)
}

// evalAnd は (and 式...) を評価します。
// いずれかの式が偽（#f）を返した時点でそれを返し、すべて真ならば最後の式の値を返します。
// 引数が0個の場合は #t を返します。
func evalAnd(exprs []Value, env *Env) (Value, error) {
	var result Value = Bool(true)
	for _, e := range exprs {
		v, err := Eval(e, env)
		if err != nil {
			return nil, err
		}
		if !IsTruthy(v) {
			return Bool(false), nil
		}
		result = v
	}
	return result, nil
}

// evalOr は (or 式...) を評価します。
// いずれかの式が真を返した時点でそれを返し、すべて偽ならば #f を返します。
func evalOr(exprs []Value, env *Env) (Value, error) {
	for _, e := range exprs {
		v, err := Eval(e, env)
		if err != nil {
			return nil, err
		}
		if IsTruthy(v) {
			return v, nil
		}
	}
	return Bool(false), nil
}
