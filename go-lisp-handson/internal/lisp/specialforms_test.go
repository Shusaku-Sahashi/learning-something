package lisp

import "testing"

// evalOne はソースコードをパースし、含まれるすべての式を順番に評価して、
// 最後の式の評価結果を返すテスト用ヘルパーです。
func evalOne(t *testing.T, src string, env *Env) Value {
	t.Helper()
	exprs, err := Parse(src)
	if err != nil {
		t.Fatalf("parse error for %q: %v", src, err)
	}
	var result Value
	for _, e := range exprs {
		result, err = Eval(e, env)
		if err != nil {
			t.Fatalf("eval error for %q: %v", src, err)
		}
	}
	return result
}

func mustParseOne(t *testing.T, src string) Value {
	t.Helper()
	exprs, err := Parse(src)
	if err != nil {
		t.Fatalf("parse error: %v", err)
	}
	return exprs[0]
}

func TestIf(t *testing.T) {
	env := NewEnv(nil)
	if v := evalOne(t, "(if #t 1 2)", env); v.(Number) != 1 {
		t.Errorf("got %v, want 1", v)
	}
	if v := evalOne(t, "(if #f 1 2)", env); v.(Number) != 2 {
		t.Errorf("got %v, want 2", v)
	}
	v := evalOne(t, "(if #f 1)", env)
	if list, ok := v.(List); !ok || len(list) != 0 {
		t.Errorf("if with false condition and no else should yield an empty list, got %#v", v)
	}
}

func TestDefine(t *testing.T) {
	env := NewEnv(nil)
	evalOne(t, "(define x 10)", env)
	if v := evalOne(t, "x", env); v.(Number) != 10 {
		t.Errorf("got %v, want 10", v)
	}
}

func TestDefineFunctionShorthand(t *testing.T) {
	env := NewEnv(nil)
	evalOne(t, "(define (identity x) x)", env)
	if v := evalOne(t, "(identity 7)", env); v.(Number) != 7 {
		t.Errorf("got %v, want 7", v)
	}
}

func TestLambdaAndClosure(t *testing.T) {
	env := NewEnv(nil)
	evalOne(t, "(define (make-const n) (lambda () n))", env)
	evalOne(t, "(define get5 (make-const 5))", env)
	if v := evalOne(t, "(get5)", env); v.(Number) != 5 {
		t.Errorf("closure did not capture n, got %v, want 5", v)
	}
}

func TestSetBang(t *testing.T) {
	env := NewEnv(nil)
	evalOne(t, "(define x 1)", env)
	evalOne(t, "(set! x 2)", env)
	if v := evalOne(t, "x", env); v.(Number) != 2 {
		t.Errorf("got %v, want 2", v)
	}
	if _, err := Eval(mustParseOne(t, "(set! undefined 1)"), env); err == nil {
		t.Error("expected error for set! on an undefined variable")
	}
}

func TestLet(t *testing.T) {
	env := NewEnv(nil)
	if v := evalOne(t, "(let ((a 1) (b 2)) b)", env); v.(Number) != 2 {
		t.Errorf("got %v, want 2", v)
	}
}

func TestBegin(t *testing.T) {
	env := NewEnv(nil)
	if v := evalOne(t, "(begin (define x 1) (set! x 2) x)", env); v.(Number) != 2 {
		t.Errorf("got %v, want 2", v)
	}
}

func TestAndOr(t *testing.T) {
	env := NewEnv(nil)
	if v := evalOne(t, "(and 1 2 3)", env); v.(Number) != 3 {
		t.Errorf("and got %v, want 3", v)
	}
	if v := evalOne(t, "(and 1 #f 3)", env); v != Bool(false) {
		t.Errorf("and got %v, want #f", v)
	}
	if v := evalOne(t, "(or #f #f 5)", env); v.(Number) != 5 {
		t.Errorf("or got %v, want 5", v)
	}
	if v := evalOne(t, "(or #f #f)", env); v != Bool(false) {
		t.Errorf("or got %v, want #f", v)
	}
}
