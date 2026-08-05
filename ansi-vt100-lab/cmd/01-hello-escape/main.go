// 01 - Hello, escape sequence.
//
// Run: go run ./cmd/01-hello-escape
//
// This example deliberately does NOT use the internal/ansi package, so you
// can see the raw bytes. "\x1b" is the ESC character; everything after it
// up to the letter "m" is a Select Graphic Rendition (SGR) instruction.
package main

import "fmt"

const esc = "\x1b"

func main() {
	// \x1b[31m -> set foreground color to red (code 31)
	// \x1b[0m  -> reset all styles back to default
	fmt.Println(esc + "[31mThis text is red." + esc + "[0m")

	// You can combine multiple SGR params separated by ";".
	// 1 = bold, 32 = green foreground
	fmt.Println(esc + "[1;32mThis text is bold and green." + esc + "[0m")

	// 4 = underline, 34 = blue foreground
	fmt.Println(esc + "[4;34mThis text is underlined and blue." + esc + "[0m")

	// If your terminal doesn't understand a sequence, it usually just
	// ignores it silently. Try piping this program's output through
	// `cat -v` to see the escape codes as literal text instead of them
	// being interpreted:
	//
	//   go run ./cmd/01-hello-escape | cat -v
	//
	// You'll see things like "^[[31m" - "^[" is how `cat -v` displays ESC
	// (0x1B).
	fmt.Println("\nTip: pipe this through `cat -v` to see the raw escape codes.")
}
