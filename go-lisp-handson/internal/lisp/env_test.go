package lisp

import "testing"

func TestEnvDefineAndGet(t *testing.T) {
	env := NewEnv(nil)
	env.Define("x", Number(10))

	v, ok := env.Get("x")
	if !ok {
		t.Fatal("expected x to be defined")
	}
	if n, ok := v.(Number); !ok || n != 10 {
		t.Errorf("x = %v, want 10", v)
	}

	if _, ok := env.Get("y"); ok {
		t.Error("y should not be defined")
	}
}

func TestEnvNestedScope(t *testing.T) {
	parent := NewEnv(nil)
	parent.Define("x", Number(1))

	child := NewEnv(parent)
	v, ok := child.Get("x")
	if !ok || v.(Number) != 1 {
		t.Errorf("child should see parent's x, got %v, %v", v, ok)
	}

	child.Define("x", Number(2))
	if v, _ := child.Get("x"); v.(Number) != 2 {
		t.Errorf("child's own x should shadow parent's, got %v", v)
	}
	if v, _ := parent.Get("x"); v.(Number) != 1 {
		t.Errorf("parent's x should be unaffected, got %v", v)
	}
}

func TestEnvSet(t *testing.T) {
	parent := NewEnv(nil)
	parent.Define("x", Number(1))
	child := NewEnv(parent)

	if err := child.Set("x", Number(99)); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if v, _ := parent.Get("x"); v.(Number) != 99 {
		t.Errorf("set! should update the environment where x was defined, got %v", v)
	}

	if err := child.Set("undefined", Number(1)); err == nil {
		t.Error("expected error when set! on an undefined variable")
	}
}
