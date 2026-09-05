package lisp

import (
	"fmt"
	"strconv"
)

// Parse はソースコード全体を読み込み、トップレベルに並んだS式をValueのスライスとして返します。
// 例えば "(+ 1 2) (* 3 4)" を渡すと、2つのList値が返ります。
func Parse(src string) ([]Value, error) {
	tokens, err := Tokenize(src)
	if err != nil {
		return nil, err
	}

	var exprs []Value
	for len(tokens) > 0 {
		var expr Value
		expr, tokens, err = readExpr(tokens)
		if err != nil {
			return nil, err
		}
		exprs = append(exprs, expr)
	}
	return exprs, nil
}

// readExpr は先頭のトークン列から1つのS式を読み取り、
// 読み取った値と「残りのトークン列」を返します。
func readExpr(tokens []string) (Value, []string, error) {
	if len(tokens) == 0 {
		return nil, nil, fmt.Errorf("式の途中で入力が終わりました")
	}

	head, rest := tokens[0], tokens[1:]

	switch head {
	case "(":
		return readList(rest)
	case ")":
		return nil, nil, fmt.Errorf("対応する '(' のない ')' があります")
	case "'":
		var quoted Value
		var err error
		quoted, rest, err = readExpr(rest)
		if err != nil {
			return nil, nil, err
		}
		return List{Symbol("quote"), quoted}, rest, nil
	default:
		return parseAtom(head), rest, nil
	}
}

// readList は最初の "(" を消費した状態で呼ばれ、対応する ")" までを読み取ります。
func readList(tokens []string) (Value, []string, error) {
	var items List
	for {
		if len(tokens) == 0 {
			return nil, nil, fmt.Errorf("リストが ')' で閉じられていません")
		}
		if tokens[0] == ")" {
			return items, tokens[1:], nil
		}
		var item Value
		var err error
		item, tokens, err = readExpr(tokens)
		if err != nil {
			return nil, nil, err
		}
		items = append(items, item)
	}
}

// parseAtom は1つのトークン（"(" ")" "'" 以外）を Number / Bool / String / Symbol に変換します。
func parseAtom(tok string) Value {
	switch tok {
	case "#t":
		return Bool(true)
	case "#f":
		return Bool(false)
	}

	if len(tok) >= 2 && tok[0] == '"' && tok[len(tok)-1] == '"' {
		if s, err := strconv.Unquote(tok); err == nil {
			return String(s)
		}
		return String(tok[1 : len(tok)-1])
	}

	if f, err := strconv.ParseFloat(tok, 64); err == nil {
		return Number(f)
	}

	return Symbol(tok)
}
