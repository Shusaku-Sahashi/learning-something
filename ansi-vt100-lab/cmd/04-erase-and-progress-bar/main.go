// 04 - Erasing + in-place updates (a progress bar).
//
// Run: go run ./cmd/04-erase-and-progress-bar
//
// The trick behind every "redraws in place" CLI tool (progress bars,
// spinners, live-updating counters) is:
//  1. "\r"             - carriage return, move cursor to column 1 (no newline)
//  2. ansi.EraseLineEnd - clear everything from the cursor to the end of line
//  3. write the new frame
//
// Without step 2, leftover characters from a longer previous frame would
// stick around after the line gets shorter.
package main

import (
	"fmt"
	"strings"
	"time"

	"ansi-vt100-lab/internal/ansi"
)

const total = 40

func render(progress int) {
	filled := progress * 30 / total
	bar := strings.Repeat("#", filled) + strings.Repeat("-", 30-filled)
	pct := progress * 100 / total

	// "\r" + EraseLineEnd is the redraw idiom. ansi.FG(2) is green.
	fmt.Printf("\r%s[%s%s%s] %3d%%", ansi.EraseLineEnd, ansi.FG(2), bar, ansi.Reset, pct)
}

func main() {
	for progress := 1; progress <= total; progress++ {
		time.Sleep(100 * time.Millisecond)
		render(progress)
	}
	fmt.Println()
	fmt.Println("Done!")
}
