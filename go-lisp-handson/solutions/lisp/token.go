package lisp

import (
	"fmt"
	"unicode"
)

// Tokenize はソースコードをトークン列に分割します。
// トークンの種類は "(" ")" "'" と、それ以外の「アトム」（シンボル・数値・文字列リテラル）です。
// 文字列リテラルはダブルクォートを含めたまま1トークンとして返します（例: `"hello"`）。
func Tokenize(src string) ([]string, error) {
	var tokens []string
	runes := []rune(src)
	i := 0
	n := len(runes)

	for i < n {
		c := runes[i]

		switch {
		case unicode.IsSpace(c):
			i++

		case c == ';':
			for i < n && runes[i] != '\n' {
				i++
			}

		case c == '(' || c == ')' || c == '\'':
			tokens = append(tokens, string(c))
			i++

		case c == '"':
			start := i
			i++
			for i < n && runes[i] != '"' {
				if runes[i] == '\\' && i+1 < n {
					i++
				}
				i++
			}
			if i >= n {
				return nil, fmt.Errorf("文字列リテラルが閉じられていません: %s", string(runes[start:]))
			}
			i++ // 閉じる " を含める
			tokens = append(tokens, string(runes[start:i]))

		default:
			start := i
			for i < n && !unicode.IsSpace(runes[i]) && runes[i] != '(' && runes[i] != ')' && runes[i] != ';' {
				i++
			}
			tokens = append(tokens, string(runes[start:i]))
		}
	}

	return tokens, nil
}
