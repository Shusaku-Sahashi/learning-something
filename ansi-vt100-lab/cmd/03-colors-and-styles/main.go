// 03 - Colors and text styles (SGR).
//
// Run: go run ./cmd/03-colors-and-styles
//
// Walks through the three color systems terminals commonly support:
//  1. 16 colors  (ESC[30-37m / ESC[90-97m) - supported almost everywhere
//  2. 256 colors (ESC[38;5;<n>m)           - most modern terminals
//  3. true color (ESC[38;2;r;g;bm)         - most modern terminals
//
// plus a few text styles (bold, underline, etc).
package main

import (
	"fmt"
	"strings"

	"ansi-vt100-lab/internal/ansi"
)

func main() {
	fmt.Println("--- 16-color palette (foreground) ---")
	names := []string{"black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"}

	var line strings.Builder
	for i, name := range names {
		fmt.Fprintf(&line, "%s%-8s%s", ansi.FG(i), name, ansi.Reset)
	}
	fmt.Println(line.String())

	var brightLine strings.Builder
	for i, name := range names {
		fmt.Fprintf(&brightLine, "%s%-14s%s", ansi.FGBright(i), "bright-"+name, ansi.Reset)
	}
	fmt.Println(brightLine.String())

	fmt.Println("\n--- Text styles ---")
	fmt.Printf("%sbold%s  %sdim%s  %sitalic%s  %sunderline%s  %sinverse%s\n",
		ansi.Bold, ansi.Reset,
		ansi.Dim, ansi.Reset,
		ansi.Italic, ansi.Reset,
		ansi.Underline, ansi.Reset,
		ansi.Inverse, ansi.Reset,
	)

	fmt.Println("\n--- 256-color cube (a slice of it) ---")
	var cube strings.Builder
	for n := 16; n < 52; n++ {
		fmt.Fprintf(&cube, "%s  %s", ansi.BG256(n), ansi.Reset)
	}
	fmt.Println(cube.String())

	fmt.Println("\n--- True color (24-bit) gradient ---")
	var gradient strings.Builder
	const steps = 40
	for i := 0; i < steps; i++ {
		r := i * 255 / steps
		g := (steps - i) * 255 / steps
		b := 128
		fmt.Fprintf(&gradient, "%s %s", ansi.BGRGB(r, g, b), ansi.Reset)
	}
	fmt.Println(gradient.String())

	fmt.Println(
		"\nNote: true-color and 256-color support depends on your terminal & the\n" +
			"COLORTERM/TERM environment variables. If the gradient above looks\n" +
			"banded instead of smooth, your terminal probably doesn't support 24-bit color.",
	)
}
