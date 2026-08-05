// 02 - Cursor movement.
//
// Run: go run ./cmd/02-cursor-movement  (Ctrl+C to quit)
//
// Bounces a "*" around inside a small box using absolute cursor
// positioning (CUP: ESC[<row>;<col>H). This is the same primitive that
// lets TUIs draw things anywhere on screen instead of only appending to
// the bottom, like a normal fmt.Println would.
package main

import (
	"fmt"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"ansi-vt100-lab/internal/ansi"
)

const (
	width     = 20
	height    = 8
	originRow = 3 // leave a couple of lines at the top for instructions
)

func moveTo(row, col int) {
	fmt.Print(ansi.CursorTo(originRow+row, col+2))
}

func drawBox() {
	fmt.Println("Bouncing cursor demo - Ctrl+C to quit")
	fmt.Println()
	for r := 0; r < height; r++ {
		fmt.Println("#" + strings.Repeat(" ", width) + "#")
	}
	fmt.Println("#" + strings.Repeat("#", width+2))
}

func main() {
	drawBox()
	fmt.Print(ansi.CursorHide)

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT)

	cleanup := func() {
		fmt.Print(ansi.CursorShow)
		fmt.Println()
		os.Exit(0)
	}

	x, y := 0, 0
	dx, dy := 1, 1

	ticker := time.NewTicker(80 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-sigCh:
			cleanup()
		case <-ticker.C:
			// Erase the previous position by overwriting it with a space.
			moveTo(y, x)
			fmt.Print(" ")

			x += dx
			y += dy
			if x <= 0 || x >= width-1 {
				dx *= -1
			}
			if y <= 0 || y >= height-1 {
				dy *= -1
			}

			moveTo(y, x)
			fmt.Print(ansi.FGBright(3) + "*" + ansi.Reset)

			// Park the real cursor below the box so it doesn't sit on top
			// of the "*".
			fmt.Print(ansi.CursorTo(originRow+height+2, 1))
		}
	}
}
