// Package lisp は、このハンズオンで作るミニLisp処理系の中核パッケージです。
package lisp

import (
	"fmt"
	"math"
	"strconv"
	"strings"
)

// Value はLisp上のすべての値が満たすインターフェースです。
// Symbol・Number・Bool・String・List・*Lambda・*Builtin がこれを実装します。
type Value interface {
	String() string
}

// Symbol は変数名や関数名などの識別子を表します。
type Symbol string

func (s Symbol) String() string { return string(s) }

// Number はLisp上の数値を表します。整数と小数を区別せず float64 で保持します。
type Number float64

func (n Number) String() string {
	f := float64(n)
	if f == math.Trunc(f) && !math.IsInf(f, 0) {
		return strconv.FormatFloat(f, 'f', -1, 64)
	}
	return strconv.FormatFloat(f, 'g', -1, 64)
}

// Bool は真偽値を表します。
type Bool bool

func (b Bool) String() string {
	if b {
		return "#t"
	}
	return "#f"
}

// String はLisp上の文字列リテラルを表します。
type String string

func (s String) String() string {
	return strconv.Quote(string(s))
}

// List は複数の値の並び（Lispでいうリスト、あるいはS式そのもの）を表します。
// 本来のLispはコンスセルの連結で表現しますが、この処理系では単純化のため
// Goのスライスで表現しています。
type List []Value

func (l List) String() string {
	parts := make([]string, len(l))
	for i, v := range l {
		parts[i] = v.String()
	}
	return "(" + strings.Join(parts, " ") + ")"
}

// Lambda はユーザーが `lambda` / `define` で作った関数（クロージャ）を表します。
type Lambda struct {
	Params []Symbol
	Body   []Value
	Env    *Env
}

func (l *Lambda) String() string {
	return fmt.Sprintf("#<lambda/%d>", len(l.Params))
}

// Builtin はGoの関数で実装された組み込み関数を表します。
type Builtin struct {
	Name string
	Fn   func(args []Value) (Value, error)
}

func (b *Builtin) String() string {
	return fmt.Sprintf("#<builtin:%s>", b.Name)
}

// IsTruthy はSchemeの慣習にならい、`#f` 以外はすべて真として扱います。
// （`0` や空リスト `()` も真になる点に注意してください。）
func IsTruthy(v Value) bool {
	if b, ok := v.(Bool); ok {
		return bool(b)
	}
	return true
}

// Equal は2つの値が「同じ値」とみなせるかどうかを判定します（Lispの `equal?`）。
// ポインタの一致ではなく、値としての構造的な等しさを見ます。
func Equal(a, b Value) bool {
	switch av := a.(type) {
	case Number:
		bv, ok := b.(Number)
		return ok && av == bv
	case Symbol:
		bv, ok := b.(Symbol)
		return ok && av == bv
	case Bool:
		bv, ok := b.(Bool)
		return ok && av == bv
	case String:
		bv, ok := b.(String)
		return ok && av == bv
	case List:
		bv, ok := b.(List)
		if !ok || len(av) != len(bv) {
			return false
		}
		for i := range av {
			if !Equal(av[i], bv[i]) {
				return false
			}
		}
		return true
	default:
		return a == b
	}
}
