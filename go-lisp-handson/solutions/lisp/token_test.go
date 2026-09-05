package lisp

import (
	"reflect"
	"testing"
)

func TestTokenize(t *testing.T) {
	tests := []struct {
		name string
		src  string
		want []string
	}{
		{
			name: "simple list",
			src:  "(+ 1 2)",
			want: []string{"(", "+", "1", "2", ")"},
		},
		{
			name: "nested list",
			src:  "(define (square x) (* x x))",
			want: []string{"(", "define", "(", "square", "x", ")", "(", "*", "x", "x", ")", ")"},
		},
		{
			name: "quote shorthand",
			src:  "'(1 2 3)",
			want: []string{"'", "(", "1", "2", "3", ")"},
		},
		{
			name: "string literal",
			src:  `(display "hello world")`,
			want: []string{"(", "display", `"hello world"`, ")"},
		},
		{
			name: "comment is ignored",
			src:  "(+ 1 2) ; これはコメント\n(* 3 4)",
			want: []string{"(", "+", "1", "2", ")", "(", "*", "3", "4", ")"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := Tokenize(tt.src)
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("Tokenize(%q) = %v, want %v", tt.src, got, tt.want)
			}
		})
	}
}

func TestTokenizeUnterminatedString(t *testing.T) {
	_, err := Tokenize(`(display "unterminated)`)
	if err == nil {
		t.Fatal("expected an error for unterminated string, got nil")
	}
}
