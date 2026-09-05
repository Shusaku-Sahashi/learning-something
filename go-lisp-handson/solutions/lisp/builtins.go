package lisp

import (
	"fmt"
	"math"
)

// NewGlobalEnv は組み込み関数を登録済みのグローバル環境を作ります。
func NewGlobalEnv() *Env {
	env := NewEnv(nil)

	def := func(name string, fn func(args []Value) (Value, error)) {
		env.Define(Symbol(name), &Builtin{Name: name, Fn: fn})
	}

	def("+", func(args []Value) (Value, error) {
		return numFold(args, 0, func(a, b float64) float64 { return a + b })
	})
	def("*", func(args []Value) (Value, error) {
		return numFold(args, 1, func(a, b float64) float64 { return a * b })
	})
	def("-", builtinSub)
	def("/", builtinDiv)
	def("mod", builtinMod)

	def("=", numCompare(func(a, b float64) bool { return a == b }))
	def("<", numCompare(func(a, b float64) bool { return a < b }))
	def(">", numCompare(func(a, b float64) bool { return a > b }))
	def("<=", numCompare(func(a, b float64) bool { return a <= b }))
	def(">=", numCompare(func(a, b float64) bool { return a >= b }))

	def("not", builtinNot)
	def("list", builtinList)
	def("cons", builtinCons)
	def("car", builtinCar)
	def("cdr", builtinCdr)
	def("null?", builtinNullP)
	def("list?", builtinListP)
	def("length", builtinLength)
	def("append", builtinAppend)
	def("equal?", builtinEqualP)
	def("display", builtinDisplay)
	def("newline", builtinNewline)

	return env
}

// numFold は "+" や "*" のように、可変長の数値引数を左から順に畳み込む処理の共通部分です。
// 例: numFold([1,2,3], 0, +) は ((0+1)+2)+3 = 6 を計算します。
func numFold(args []Value, init float64, op func(a, b float64) float64) (Value, error) {
	acc := init
	for _, a := range args {
		n, ok := a.(Number)
		if !ok {
			return nil, fmt.Errorf("数値が必要です: %s", a.String())
		}
		acc = op(acc, float64(n))
	}
	return Number(acc), nil
}

// builtinSub は "-" を実装します。
func builtinSub(args []Value) (Value, error) {
	nums, err := toNumbers(args)
	if err != nil {
		return nil, err
	}
	switch len(nums) {
	case 0:
		return nil, fmt.Errorf("- は最低1つの引数が必要です")
	case 1:
		return Number(-nums[0]), nil
	default:
		acc := nums[0]
		for _, n := range nums[1:] {
			acc -= n
		}
		return Number(acc), nil
	}
}

// builtinDiv は "/" を実装します。
func builtinDiv(args []Value) (Value, error) {
	nums, err := toNumbers(args)
	if err != nil {
		return nil, err
	}
	if len(nums) == 0 {
		return nil, fmt.Errorf("/ は最低1つの引数が必要です")
	}
	acc := nums[0]
	if len(nums) == 1 {
		if acc == 0 {
			return nil, fmt.Errorf("ゼロ除算です")
		}
		return Number(1 / acc), nil
	}
	for _, n := range nums[1:] {
		if n == 0 {
			return nil, fmt.Errorf("ゼロ除算です")
		}
		acc /= n
	}
	return Number(acc), nil
}

// builtinMod は "mod" を実装します。
func builtinMod(args []Value) (Value, error) {
	nums, err := toNumbers(args)
	if err != nil {
		return nil, err
	}
	if len(nums) != 2 {
		return nil, fmt.Errorf("mod は引数を2つ取ります")
	}
	if nums[1] == 0 {
		return nil, fmt.Errorf("ゼロ除算です")
	}
	return Number(math.Mod(nums[0], nums[1])), nil
}

// numCompare は "=" "<" ">" "<=" ">=" を作るための「関数を返す関数」です。
func numCompare(cmp func(a, b float64) bool) func(args []Value) (Value, error) {
	return func(args []Value) (Value, error) {
		nums, err := toNumbers(args)
		if err != nil {
			return nil, err
		}
		if len(nums) < 2 {
			return nil, fmt.Errorf("比較には最低2つの引数が必要です")
		}
		for i := 0; i < len(nums)-1; i++ {
			if !cmp(nums[i], nums[i+1]) {
				return Bool(false), nil
			}
		}
		return Bool(true), nil
	}
}

// toNumbers は引数のスライスをすべて Number として取り出します。
func toNumbers(args []Value) ([]float64, error) {
	nums := make([]float64, len(args))
	for i, a := range args {
		n, ok := a.(Number)
		if !ok {
			return nil, fmt.Errorf("数値が必要です: %s", a.String())
		}
		nums[i] = float64(n)
	}
	return nums, nil
}

// builtinNot は "not" を実装します。
func builtinNot(args []Value) (Value, error) {
	if len(args) != 1 {
		return nil, fmt.Errorf("not は引数を1つ取ります")
	}
	return Bool(!IsTruthy(args[0])), nil
}

// builtinList は "list" を実装します。
func builtinList(args []Value) (Value, error) {
	return List(append([]Value{}, args...)), nil
}

// builtinCons は "cons" を実装します。
func builtinCons(args []Value) (Value, error) {
	if len(args) != 2 {
		return nil, fmt.Errorf("cons は引数を2つ取ります")
	}
	rest, ok := args[1].(List)
	if !ok {
		return nil, fmt.Errorf("cons の2つ目の引数はリストである必要があります")
	}
	return append(List{args[0]}, rest...), nil
}

// builtinCar は "car" を実装します。
func builtinCar(args []Value) (Value, error) {
	list, err := requireNonEmptyList(args, "car")
	if err != nil {
		return nil, err
	}
	return list[0], nil
}

// builtinCdr は "cdr" を実装します。
func builtinCdr(args []Value) (Value, error) {
	list, err := requireNonEmptyList(args, "cdr")
	if err != nil {
		return nil, err
	}
	return list[1:], nil
}

// requireNonEmptyList は car / cdr のための共通の引数チェックです。
func requireNonEmptyList(args []Value, name string) (List, error) {
	if len(args) != 1 {
		return nil, fmt.Errorf("%s は引数を1つ取ります", name)
	}
	list, ok := args[0].(List)
	if !ok || len(list) == 0 {
		return nil, fmt.Errorf("%s は空でないリストに対して呼び出す必要があります", name)
	}
	return list, nil
}

// builtinNullP は "null?" を実装します。
func builtinNullP(args []Value) (Value, error) {
	if len(args) != 1 {
		return nil, fmt.Errorf("null? は引数を1つ取ります")
	}
	list, ok := args[0].(List)
	return Bool(ok && len(list) == 0), nil
}

// builtinListP は "list?" を実装します。
func builtinListP(args []Value) (Value, error) {
	if len(args) != 1 {
		return nil, fmt.Errorf("list? は引数を1つ取ります")
	}
	_, ok := args[0].(List)
	return Bool(ok), nil
}

// builtinLength は "length" を実装します。
func builtinLength(args []Value) (Value, error) {
	if len(args) != 1 {
		return nil, fmt.Errorf("length は引数を1つ取ります")
	}
	list, ok := args[0].(List)
	if !ok {
		return nil, fmt.Errorf("length の引数はリストである必要があります")
	}
	return Number(len(list)), nil
}

// builtinAppend は "append" を実装します。
func builtinAppend(args []Value) (Value, error) {
	var result List
	for _, a := range args {
		list, ok := a.(List)
		if !ok {
			return nil, fmt.Errorf("append の引数はすべてリストである必要があります")
		}
		result = append(result, list...)
	}
	return result, nil
}

// builtinEqualP は "equal?" を実装します。
func builtinEqualP(args []Value) (Value, error) {
	if len(args) != 2 {
		return nil, fmt.Errorf("equal? は引数を2つ取ります")
	}
	return Bool(Equal(args[0], args[1])), nil
}

// builtinDisplay は "display" を実装します。
func builtinDisplay(args []Value) (Value, error) {
	for _, a := range args {
		fmt.Print(displayString(a))
	}
	return List{}, nil
}

// displayString は表示用の文字列表現を返します。
func displayString(v Value) string {
	if s, ok := v.(String); ok {
		return string(s)
	}
	return v.String()
}

// builtinNewline は "newline" を実装します。
func builtinNewline(args []Value) (Value, error) {
	fmt.Println()
	return List{}, nil
}
