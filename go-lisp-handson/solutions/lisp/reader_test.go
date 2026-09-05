package lisp

import "testing"

func TestParseAtoms(t *testing.T) {
	exprs, err := Parse(`42 3.14 #t #f foo "bar"`)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	want := []string{"42", "3.14", "#t", "#f", "foo", `"bar"`}
	if len(exprs) != len(want) {
		t.Fatalf("got %d exprs, want %d", len(exprs), len(want))
	}
	for i, e := range exprs {
		if e.String() != want[i] {
			t.Errorf("exprs[%d] = %s, want %s", i, e.String(), want[i])
		}
	}

	if _, ok := exprs[0].(Number); !ok {
		t.Errorf("42 should parse as Number, got %T", exprs[0])
	}
	if _, ok := exprs[4].(Symbol); !ok {
		t.Errorf("foo should parse as Symbol, got %T", exprs[4])
	}
}

func TestParseList(t *testing.T) {
	exprs, err := Parse("(+ 1 (* 2 3))")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(exprs) != 1 {
		t.Fatalf("expected 1 top-level expr, got %d", len(exprs))
	}
	list, ok := exprs[0].(List)
	if !ok || len(list) != 3 {
		t.Fatalf("expected a 3-element list, got %#v", exprs[0])
	}
	inner, ok := list[2].(List)
	if !ok || len(inner) != 3 {
		t.Fatalf("expected nested list, got %#v", list[2])
	}
}

func TestParseQuote(t *testing.T) {
	exprs, err := Parse("'(1 2 3)")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	list, ok := exprs[0].(List)
	if !ok || len(list) != 2 {
		t.Fatalf("expected (quote (1 2 3)), got %#v", exprs[0])
	}
	if sym, ok := list[0].(Symbol); !ok || sym != "quote" {
		t.Errorf("expected quote symbol, got %#v", list[0])
	}
}

func TestParseUnbalanced(t *testing.T) {
	if _, err := Parse("(+ 1 2"); err == nil {
		t.Error("expected error for unbalanced parens, got nil")
	}
	if _, err := Parse("+ 1 2)"); err == nil {
		t.Error("expected error for stray ), got nil")
	}
}
