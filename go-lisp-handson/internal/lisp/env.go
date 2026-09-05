package lisp

// Env は変数名から値へのマッピングを保持する「環境」です。
// 親環境へのポインタを持つことで、レキシカルスコープとクロージャを実現します。
type Env struct {
	vars   map[Symbol]Value
	parent *Env
}

// NewEnv は親環境を指定して新しい環境を作ります。
// グローバル環境を作る場合は parent に nil を渡します。
func NewEnv(parent *Env) *Env {
	return &Env{
		vars:   make(map[Symbol]Value),
		parent: parent,
	}
}

// STEP 3: 環境（変数のスコープ）を実装しましょう。
//
// Get はシンボルの値を探します。まず現在の環境 (e.vars) を見て、
// 見つからなければ親環境 (e.parent) をたどっていきます。
// グローバル環境（parent が nil）まで見ても見つからなければ、
// 2番目の戻り値に false を返してください。
func (e *Env) Get(sym Symbol) (Value, bool) {
	// TODO: 実装してください。
	panic("TODO: Env.Get を実装してください")
}

// Define は現在の環境に新しい変数を（既にあれば上書きして）定義します。
// 親をたどる必要はありません。
func (e *Env) Define(sym Symbol, val Value) {
	// TODO: 実装してください。
	panic("TODO: Env.Define を実装してください")
}

// Set は既存の変数に値を再代入します（Schemeの `set!` に対応）。
// Get と似ていますが、値を探すのではなく「変数がどの環境で定義されているか」を
// 見つけて、その環境の値を書き換えます。
// 変数がどの環境にも見つからない場合はエラーを返してください（fmt.Errorf を使います）。
func (e *Env) Set(sym Symbol, val Value) error {
	// TODO: 実装してください。
	panic("TODO: Env.Set を実装してください")
}
