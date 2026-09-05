package lisp

import "fmt"

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

// Get はシンボルの値を探します。現在の環境になければ親をたどっていきます。
func (e *Env) Get(sym Symbol) (Value, bool) {
	for env := e; env != nil; env = env.parent {
		if v, ok := env.vars[sym]; ok {
			return v, true
		}
	}
	return nil, false
}

// Define は現在の環境に新しい変数を（既にあれば上書きして）定義します。
func (e *Env) Define(sym Symbol, val Value) {
	e.vars[sym] = val
}

// Set は既存の変数に値を再代入します（Schemeの `set!` に対応）。
// 変数がどの環境にも見つからない場合はエラーを返します。
func (e *Env) Set(sym Symbol, val Value) error {
	for env := e; env != nil; env = env.parent {
		if _, ok := env.vars[sym]; ok {
			env.vars[sym] = val
			return nil
		}
	}
	return fmt.Errorf("未定義の変数への set!: %s", sym)
}
