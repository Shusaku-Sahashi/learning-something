// 05 - The alternate screen buffer.
//
// Run: go run ./cmd/05-alternate-screen-clock  (Ctrl+C to quit)
//
// Full-screen tools like vim, less, htop, and fzf don't want to spam your
// shell's scrollback history. Instead they switch to a second, separate
// screen buffer (ESC[?1049h), draw whatever they want on it, and then
// switch back (ESC[?1049l) when they exit - at which point your terminal
// looks exactly like it did before the program ran.
package main

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"ansi-vt100-lab/internal/ansi"
)

func frame() {
	now := time.Now().Format("15:04:05")
	fmt.Print(ansi.CursorTo(1, 1))
	fmt.Print(ansi.EraseScreen)
	fmt.Print(ansi.CursorTo(3, 4))
	fmt.Print(ansi.Bold + ansi.FG(6) + "ANSI alternate-screen demo" + ansi.Reset)
	fmt.Print(ansi.CursorTo(5, 4))
	fmt.Print("Current time: " + ansi.FGBright(3) + now + ansi.Reset)
	fmt.Print(ansi.CursorTo(7, 4))
	fmt.Print("Press Ctrl+C to return to your normal shell screen.")
}

func main() {
	fmt.Print(ansi.AltScreenEnter)
	fmt.Print(ansi.CursorHide)

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT)

	cleanup := func() {
		fmt.Print(ansi.CursorShow)
		// Leaving the alternate screen restores whatever was on screen
		// before this program started - none of the clock frames end up
		// in scrollback.
		fmt.Print(ansi.AltScreenExit)
		os.Exit(0)
	}

	frame()
	ticker := time.NewTicker(250 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-sigCh:
			cleanup()
		case <-ticker.C:
			frame()
		}
	}
}
