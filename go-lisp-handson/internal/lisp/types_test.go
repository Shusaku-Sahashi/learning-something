package lisp

import "testing"

func TestIsTruthy(t *testing.T) {
	if !IsTruthy(Number(0)) {
		t.Error("0 should be truthy in this Lisp (only #f is falsy)")
	}
	if !IsTruthy(List{}) {
		t.Error("empty list should be truthy (only #f is falsy)")
	}
	if IsTruthy(Bool(false)) {
		t.Error("#f should be falsy")
	}
	if !IsTruthy(Bool(true)) {
		t.Error("#t should be truthy")
	}
}

func TestEqual(t *testing.T) {
	if !Equal(Number(1), Number(1)) {
		t.Error("Number(1) should equal Number(1)")
	}
	if Equal(Number(1), Number(2)) {
		t.Error("Number(1) should not equal Number(2)")
	}
	if !Equal(List{Number(1), Number(2)}, List{Number(1), Number(2)}) {
		t.Error("structurally equal lists should be Equal")
	}
	if Equal(List{Number(1)}, List{Number(1), Number(2)}) {
		t.Error("lists of different lengths should not be Equal")
	}
}

func TestValueString(t *testing.T) {
	cases := []struct {
		v    Value
		want string
	}{
		{Number(42), "42"},
		{Symbol("foo"), "foo"},
		{Bool(true), "#t"},
		{Bool(false), "#f"},
		{List{Number(1), Number(2)}, "(1 2)"},
	}
	for _, c := range cases {
		if got := c.v.String(); got != c.want {
			t.Errorf("%#v.String() = %q, want %q", c.v, got, c.want)
		}
	}
}
