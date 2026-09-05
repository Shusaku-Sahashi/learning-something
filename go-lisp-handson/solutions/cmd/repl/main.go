// repl は go-lisp-handson で作ったLisp処理系を対話的に試すためのコマンドです。
//
// 引数なしで実行すると対話的なREPL (Read-Eval-Print Loop) を起動します。
// ファイルパスを1つ渡すと、そのファイルをスクリプトとして実行します。
//
//	go run ./cmd/repl
//	go run ./cmd/repl ../examples/factorial.lisp
package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"go-lisp-handson/solutions/lisp"
)

func main() {
	if len(os.Args) > 1 {
		runFile(os.Args[1])
		return
	}
	repl()
}

func runFile(path string) {
	data, err := os.ReadFile(path)
	if err != nil {
		fmt.Fprintln(os.Stderr, "エラー:", err)
		os.Exit(1)
	}

	env := lisp.NewGlobalEnv()
	exprs, err := lisp.Parse(string(data))
	if err != nil {
		fmt.Fprintln(os.Stderr, "構文エラー:", err)
		os.Exit(1)
	}
	for _, expr := range exprs {
		if _, err := lisp.Eval(expr, env); err != nil {
			fmt.Fprintln(os.Stderr, "実行時エラー:", err)
			os.Exit(1)
		}
	}
}

func repl() {
	env := lisp.NewGlobalEnv()
	scanner := bufio.NewScanner(os.Stdin)
	fmt.Println("Mini Lisp REPL (終了するには Ctrl+D)")

	var buf strings.Builder
	depth := 0

	for {
		if depth == 0 {
			fmt.Print("lisp> ")
		} else {
			fmt.Print("....> ")
		}
		if !scanner.Scan() {
			fmt.Println()
			return
		}

		line := scanner.Text()
		depth += strings.Count(line, "(") - strings.Count(line, ")")
		buf.WriteString(line)
		buf.WriteString("\n")

		if depth > 0 {
			continue
		}
		depth = 0

		src := buf.String()
		buf.Reset()
		if strings.TrimSpace(src) == "" {
			continue
		}

		exprs, err := lisp.Parse(src)
		if err != nil {
			fmt.Println("構文エラー:", err)
			continue
		}
		for _, expr := range exprs {
			result, err := lisp.Eval(expr, env)
			if err != nil {
				fmt.Println("エラー:", err)
				continue
			}
			fmt.Println(result.String())
		}
	}
}
