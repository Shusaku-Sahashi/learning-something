// 06 - Suggest box (the payoff example).
//
// Run: go run ./cmd/06-suggest-box
//
// This is the pattern behind the kind of terminal autocomplete dropdown
// IRIS (https://github.com/versenilvis/IRIS) and similar tools draw: a
// text input with a live-filtered list of suggestions rendered directly
// below it, redrawn on every keystroke without disturbing the rest of the
// terminal.
//
// The building blocks, all from internal/ansi:
//   - raw mode stdin (golang.org/x/term), so keys are delivered one at a
//     time instead of only after the user presses Enter - that part is the
//     OS/terminal driver's job, not ANSI's.
//   - ansi.CursorToColumn(1) + ansi.EraseLine -> redraw a single line in place
//   - ansi.CursorDown(n) / ansi.CursorUp(n)   -> move between the input line
//     and the suggestion lines below it
//   - ansi.Inverse                            -> highlight the selected suggestion
//
// Controls: type to filter, Up/Down to move the selection, Enter to
// accept, Esc or Ctrl+C to quit.
package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"
	"time"

	"golang.org/x/term"

	"ansi-vt100-lab/internal/ansi"
)

var words = []string{
	"apple", "apricot", "avocado", "banana", "blackberry", "blueberry",
	"cherry", "coconut", "cranberry", "date", "dragonfruit", "fig",
	"grape", "grapefruit", "guava", "kiwi", "lemon", "lime", "lychee",
	"mango", "melon", "nectarine", "orange", "papaya", "passionfruit",
	"peach", "pear", "persimmon", "pineapple", "plum", "pomegranate",
	"raspberry", "strawberry", "tangerine", "watermelon",
}

const (
	maxSuggestions = 5
	prompt         = "? "
)

var (
	input    string
	selected int
)

func matches() []string {
	if input == "" {
		return nil
	}
	needle := strings.ToLower(input)
	var out []string
	for _, w := range words {
		if strings.HasPrefix(w, needle) {
			out = append(out, w)
			if len(out) == maxSuggestions {
				break
			}
		}
	}
	return out
}

func redraw() {
	list := matches()
	if selected >= len(list) {
		selected = len(list) - 1
	}
	if selected < 0 {
		selected = 0
	}

	// Redraw the input line in place.
	fmt.Print(ansi.CursorToColumn(1) + ansi.EraseLine)
	fmt.Print(ansi.Bold + prompt + ansi.Reset + input)

	// Redraw each suggestion slot below it, blank or highlighted.
	for i := 0; i < maxSuggestions; i++ {
		fmt.Print(ansi.CursorDown(1) + ansi.CursorToColumn(1) + ansi.EraseLine)
		if i < len(list) {
			if i == selected {
				fmt.Print(ansi.Inverse + "> " + list[i] + ansi.Reset)
			} else {
				fmt.Print("  " + list[i])
			}
		}
	}

	// Hop back up to the input line and put the text cursor right after
	// whatever the user has typed so far.
	fmt.Print(ansi.CursorUp(maxSuggestions))
	fmt.Print(ansi.CursorToColumn(len(prompt) + len(input) + 1))
}

func cleanup(oldState *term.State, finalMessage string) {
	fmt.Print(ansi.CursorDown(maxSuggestions) + ansi.CursorToColumn(1))
	fmt.Print(ansi.CursorShow)
	term.Restore(int(os.Stdin.Fd()), oldState)
	if finalMessage != "" {
		fmt.Println(finalMessage)
	}
	os.Exit(0)
}

// startByteReader launches a single goroutine that reads stdin one byte at
// a time and feeds it into the returned channel. It runs for the lifetime
// of the program; the channel is closed on EOF/error.
//
// We read this way (rather than calling Read directly wherever we need a
// byte) so that readKey below can race a channel receive against a timer
// with select/time.After. Go has no portable way to put a deadline on an
// arbitrary already-open file descriptor - os.File.SetReadDeadline works
// for sockets and pipes but can fail with "file type does not support
// deadline" for an inherited terminal fd, depending on the OS/environment.
// Routing everything through a channel sidesteps that entirely: the
// blocking Read happens in its own goroutine, and the main goroutine just
// waits on the channel with a timeout.
func startByteReader(stdin *os.File) <-chan byte {
	ch := make(chan byte)
	go func() {
		r := bufio.NewReader(stdin)
		for {
			b, err := r.ReadByte()
			if err != nil {
				close(ch)
				return
			}
			ch <- b
		}
	}()
	return ch
}

// readKey assembles one logical key from the byte stream: a single byte
// (control character or printable rune byte), a lone ESC, or a 3-byte
// arrow-key sequence (ESC [ A/B/C/D). ok is false once stdin is closed.
//
// A real Escape keypress and the start of an arrow-key sequence both begin
// with the same 0x1b byte. Terminals send arrow-key sequences as a single
// burst, so after seeing ESC we race the next byte against a short timer;
// if nothing shows up in time, we treat it as a standalone Escape. This is
// the same trick readline-style libraries use.
func readKey(bytes <-chan byte) (key string, ok bool) {
	b, open := <-bytes
	if !open {
		return "", false
	}
	if b != 0x1b {
		return string(b), true
	}

	select {
	case b2, open := <-bytes:
		if !open || b2 != '[' {
			// Not an arrow sequence - treat the ESC as standalone. (For
			// simplicity this demo doesn't re-inject b2; a stray non-'['
			// byte right after ESC is rare enough to ignore here.)
			return "\x1b", true
		}
		b3, open := <-bytes
		if !open {
			return "\x1b", true
		}
		return "\x1b[" + string(b3), true
	case <-time.After(50 * time.Millisecond):
		return "\x1b", true
	}
}

func handleKey(oldState *term.State, key string) {
	list := matches()

	switch key {
	case "\x03": // Ctrl+C
		cleanup(oldState, "")
		return
	case "\x1b": // lone Escape
		cleanup(oldState, "Cancelled.")
		return
	case "\x1b[A": // Up arrow
		if selected > 0 {
			selected--
		}
		redraw()
		return
	case "\x1b[B": // Down arrow
		if selected < len(list)-1 {
			selected++
		}
		redraw()
		return
	case "\r", "\n": // Enter
		if len(list) > 0 {
			input = list[selected]
		}
		redraw()
		cleanup(oldState, "Selected: "+input)
		return
	case "\x7f", "\b": // Backspace
		if len(input) > 0 {
			input = input[:len(input)-1]
		}
		selected = 0
		redraw()
		return
	}

	if len(key) == 1 && key[0] >= ' ' {
		input += key
		selected = 0
		redraw()
	}
}

func main() {
	fd := int(os.Stdin.Fd())
	if !term.IsTerminal(fd) {
		fmt.Fprintln(os.Stderr, "This demo needs an interactive terminal (a TTY) to run.")
		os.Exit(1)
	}

	fmt.Println("Type a fruit name. Up/Down to select, Enter to accept, Esc/Ctrl+C to quit.")
	fmt.Println()

	// Reserve the input line + suggestion lines in the terminal buffer
	// before we start moving the cursor around, so redraw() never has to
	// worry about scrolling mid-frame.
	fmt.Print(strings.Repeat("\r\n", maxSuggestions))
	fmt.Print(ansi.CursorUp(maxSuggestions))
	fmt.Print(ansi.CursorHide)
	redraw()

	oldState, err := term.MakeRaw(fd)
	if err != nil {
		fmt.Fprintln(os.Stderr, "failed to enter raw mode:", err)
		os.Exit(1)
	}

	bytes := startByteReader(os.Stdin)
	for {
		key, ok := readKey(bytes)
		if !ok {
			cleanup(oldState, "")
		}
		handleKey(oldState, key)
	}
}
