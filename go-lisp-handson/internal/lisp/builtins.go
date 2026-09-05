package lisp

import "fmt"

// このファイルを実装する際、builtinMod では "math" パッケージの math.Mod を使います。
// 上部の import に "math" を追加してください。

// NewGlobalEnv は組み込み関数を登録済みのグローバル環境を作ります。
// 「Lispのシンボル名」と「それを実装するGoの関数」を対応づけているだけなので、
// この関数自体を変更する必要はありません。ここから呼ばれている各関数の中身を実装してください。
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
// (- 5) は -5 (単項マイナス)、(- 10 3 2) は 10-3-2=5 になります。
func builtinSub(args []Value) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: builtinSub を実装してください")
}

// builtinDiv は "/" を実装します。
// (/ 2) は 1/2、(/ 100 5 2) は 100/5/2=10 になります。ゼロ除算はエラーにしてください。
func builtinDiv(args []Value) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: builtinDiv を実装してください")
}

// builtinMod は "mod" を実装します。(mod 7 3) は 1 になります。
func builtinMod(args []Value) (Value, error) {
	// TODO: 実装してください。ヒント: math.Mod を使います。
	panic("TODO: builtinMod を実装してください")
}

// numCompare は "=" "<" ">" "<=" ">=" のように、隣り合う数値をすべて cmp で
// 比較していく処理を作るための「関数を返す関数」です。
// 例: (< 1 2 3) は 1<2 かつ 2<3 なので #t になります。
func numCompare(cmp func(a, b float64) bool) func(args []Value) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: numCompare を実装してください")
}

// toNumbers は引数のスライスをすべて Number として取り出します。
// Number でない値が含まれていた場合はエラーを返します。
func toNumbers(args []Value) ([]float64, error) {
	// TODO: 実装してください。
	panic("TODO: toNumbers を実装してください")
}

// builtinNot は "not" を実装します。#f のみを真とみなす IsTruthy の逆を返します。
func builtinNot(args []Value) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: builtinNot を実装してください")
}

// builtinList は "list" を実装します。渡された引数をそのままリストにして返します。
func builtinList(args []Value) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: builtinList を実装してください")
}

// builtinCons は "cons" を実装します。(cons 1 (list 2 3)) は (1 2 3) になります。
// 2つ目の引数がリストでない場合はエラーにしてください。
func builtinCons(args []Value) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: builtinCons を実装してください")
}

// builtinCar は "car" を実装します。リストの先頭要素を返します。
// requireNonEmptyList を使うと、引数チェックが楽になります。
func builtinCar(args []Value) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: builtinCar を実装してください")
}

// builtinCdr は "cdr" を実装します。リストの先頭を除いた残りを返します。
func builtinCdr(args []Value) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: builtinCdr を実装してください")
}

// requireNonEmptyList は car / cdr のための共通の引数チェックです。
// 引数が1つのリストであり、かつ空でないことを確認します。
func requireNonEmptyList(args []Value, name string) (List, error) {
	// TODO: 実装してください。
	panic("TODO: requireNonEmptyList を実装してください")
}

// builtinNullP は "null?" を実装します。空リストなら #t を返します。
func builtinNullP(args []Value) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: builtinNullP を実装してください")
}

// builtinListP は "list?" を実装します。引数がリストなら #t を返します。
func builtinListP(args []Value) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: builtinListP を実装してください")
}

// builtinLength は "length" を実装します。リストの要素数を返します。
func builtinLength(args []Value) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: builtinLength を実装してください")
}

// builtinAppend は "append" を実装します。複数のリストを連結した1つのリストを返します。
func builtinAppend(args []Value) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: builtinAppend を実装してください")
}

// builtinEqualP は "equal?" を実装します。types.go の Equal 関数を使ってください。
func builtinEqualP(args []Value) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: builtinEqualP を実装してください")
}

// builtinDisplay は "display" を実装します。引数をそのまま標準出力に書き出します。
// 文字列 (String) はダブルクォート無しで、それ以外は String() の結果をそのまま出力します。
// displayString ヘルパーを使ってください。
func builtinDisplay(args []Value) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: builtinDisplay を実装してください")
}

// displayString は表示用の文字列表現を返します。
// String型はダブルクォートを外し、それ以外は Value.String() をそのまま使います。
func displayString(v Value) string {
	// TODO: 実装してください。
	panic("TODO: displayString を実装してください")
}

// builtinNewline は "newline" を実装します。改行を1つ出力するだけです。
func builtinNewline(args []Value) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: builtinNewline を実装してください")
}
