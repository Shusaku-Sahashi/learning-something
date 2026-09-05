package lisp

import "testing"

func TestEvalSelfEvaluating(t *testing.T) {
	env := NewEnv(nil)
	cases := []Value{Number(42), String("hi"), Bool(true), Bool(false)}
	for _, v := range cases {
		got, err := Eval(v, env)
		if err != nil {
			t.Fatalf("unexpected error evaluating %v: %v", v, err)
		}
		if got != v {
			t.Errorf("Eval(%v) = %v, want %v (self-evaluating)", v, got, v)
		}
	}
}

func TestEvalSymbolLookup(t *testing.T) {
	env := NewEnv(nil)
	env.Define("x", Number(10))

	got, err := Eval(Symbol("x"), env)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.(Number) != 10 {
		t.Errorf("got %v, want 10", got)
	}

	if _, err := Eval(Symbol("undefined"), env); err == nil {
		t.Error("expected error for undefined variable")
	}
}

func TestEvalQuote(t *testing.T) {
	env := NewEnv(nil)
	exprs, err := Parse("(quote (1 2 3))")
	if err != nil {
		t.Fatalf("parse error: %v", err)
	}
	got, err := Eval(exprs[0], env)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	list, ok := got.(List)
	if !ok || len(list) != 3 {
		t.Fatalf("got %#v, want a 3-element list", got)
	}
}

func TestEvalEmptyList(t *testing.T) {
	env := NewEnv(nil)
	got, err := Eval(List{}, env)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if list, ok := got.(List); !ok || len(list) != 0 {
		t.Errorf("got %#v, want empty list", got)
	}
}

func TestEvalFunctionCallWithBuiltin(t *testing.T) {
	env := NewEnv(nil)
	double := &Builtin{
		Name: "double",
		Fn: func(args []Value) (Value, error) {
			return Number(float64(args[0].(Number)) * 2), nil
		},
	}
	env.Define("double", double)

	exprs, err := Parse("(double 21)")
	if err != nil {
		t.Fatalf("parse error: %v", err)
	}
	got, err := Eval(exprs[0], env)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.(Number) != 42 {
		t.Errorf("got %v, want 42", got)
	}
}

func TestEvalNestedFunctionCall(t *testing.T) {
	env := NewEnv(nil)
	add := &Builtin{
		Name: "add",
		Fn: func(args []Value) (Value, error) {
			return Number(float64(args[0].(Number)) + float64(args[1].(Number))), nil
		},
	}
	env.Define("add", add)

	exprs, err := Parse("(add (add 1 2) 3)")
	if err != nil {
		t.Fatalf("parse error: %v", err)
	}
	got, err := Eval(exprs[0], env)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.(Number) != 6 {
		t.Errorf("got %v, want 6", got)
	}
}
