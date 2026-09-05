package lisp

import "testing"

func TestArithmetic(t *testing.T) {
	env := NewGlobalEnv()
	cases := map[string]float64{
		"(+ 1 2 3)":   6,
		"(- 10 3 2)":  5,
		"(- 5)":       -5,
		"(* 2 3 4)":   24,
		"(/ 100 5 2)": 10,
		"(mod 7 3)":   1,
	}
	for src, want := range cases {
		v := evalOne(t, src, env)
		n, ok := v.(Number)
		if !ok || float64(n) != want {
			t.Errorf("%s = %v, want %v", src, v, want)
		}
	}
}

func TestComparisons(t *testing.T) {
	env := NewGlobalEnv()
	trueCases := []string{"(= 1 1)", "(< 1 2 3)", "(> 3 2 1)", "(<= 1 1 2)", "(>= 3 3 2)"}
	for _, src := range trueCases {
		if v := evalOne(t, src, env); v != Bool(true) {
			t.Errorf("%s = %v, want #t", src, v)
		}
	}
	falseCases := []string{"(= 1 2)", "(< 3 2)", "(> 1 2)"}
	for _, src := range falseCases {
		if v := evalOne(t, src, env); v != Bool(false) {
			t.Errorf("%s = %v, want #f", src, v)
		}
	}
}

func TestListOps(t *testing.T) {
	env := NewGlobalEnv()
	if v := evalOne(t, "(car (list 1 2 3))", env); v.(Number) != 1 {
		t.Errorf("car = %v, want 1", v)
	}
	if v := evalOne(t, "(length (cdr (list 1 2 3)))", env); v.(Number) != 2 {
		t.Errorf("length of cdr = %v, want 2", v)
	}
	if v := evalOne(t, "(cons 1 (list 2 3))", env); v.String() != "(1 2 3)" {
		t.Errorf("cons = %v, want (1 2 3)", v)
	}
	if v := evalOne(t, "(null? (list))", env); v != Bool(true) {
		t.Errorf("null? on empty list should be #t, got %v", v)
	}
	if v := evalOne(t, "(append (list 1 2) (list 3 4))", env); v.String() != "(1 2 3 4)" {
		t.Errorf("append = %v, want (1 2 3 4)", v)
	}
	if v := evalOne(t, `(equal? (list 1 2) (list 1 2))`, env); v != Bool(true) {
		t.Errorf("equal? should be #t for structurally equal lists, got %v", v)
	}
}

func TestRecursiveFactorial(t *testing.T) {
	env := NewGlobalEnv()
	evalOne(t, `
		(define (fact n)
		  (if (= n 0)
		      1
		      (* n (fact (- n 1)))))
	`, env)
	if v := evalOne(t, "(fact 5)", env); v.(Number) != 120 {
		t.Errorf("(fact 5) = %v, want 120", v)
	}
}

func TestRecursiveFibonacci(t *testing.T) {
	env := NewGlobalEnv()
	evalOne(t, `
		(define (fib n)
		  (if (< n 2)
		      n
		      (+ (fib (- n 1)) (fib (- n 2)))))
	`, env)
	if v := evalOne(t, "(fib 10)", env); v.(Number) != 55 {
		t.Errorf("(fib 10) = %v, want 55", v)
	}
}
