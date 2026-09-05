package lisp

import "fmt"

// Apply は関数値 fn を引数 args に適用します。
// fn が *Builtin ならGoの関数をそのまま呼び出し、*Lambda なら
// パラメータをローカル環境に束縛してから本体を評価します。
func Apply(fn Value, args []Value) (Value, error) {
	switch f := fn.(type) {
	case *Builtin:
		return f.Fn(args)

	case *Lambda:
		if len(args) != len(f.Params) {
			return nil, fmt.Errorf("引数の数が違います: %d個必要ですが%d個渡されました", len(f.Params), len(args))
		}
		callEnv := NewEnv(f.Env)
		for i, p := range f.Params {
			callEnv.Define(p, args[i])
		}
		return evalBody(f.Body, callEnv)

	default:
		return nil, fmt.Errorf("関数として呼び出せない値です: %s", fn.String())
	}
}
