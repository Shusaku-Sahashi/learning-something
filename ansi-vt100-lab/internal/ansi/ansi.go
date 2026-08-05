// Package ansi is a minimal, dependency-free ANSI / VT100 escape sequence
// toolkit built for learning purposes.
//
// Every terminal escape sequence starts with the ESC byte (0x1B). Most of
// the sequences used here are "CSI" (Control Sequence Introducer)
// sequences, which look like:
//
//	ESC [ <params> <final-byte>
//	\x1b[   31       m
//	 ^      ^        ^
//	 CSI    param    "m" = SGR (Select Graphic Rendition)
//
// Every function in this package just concatenates plain strings, so you
// can see exactly what bytes get sent to the terminal. Real projects would
// reach for something like github.com/gdamore/tcell or
// github.com/charmbracelet/lipgloss, but the point of this lab is to
// understand what those libraries do under the hood.
package ansi

import "fmt"

const (
	Esc = "\x1b"
	CSI = Esc + "["
)

// --- Cursor movement --------------------------------------------------

// CursorUp/Down/Forward/Back move the cursor n cells in that direction.
func CursorUp(n int) string      { return fmt.Sprintf("%s%dA", CSI, n) }
func CursorDown(n int) string    { return fmt.Sprintf("%s%dB", CSI, n) }
func CursorForward(n int) string { return fmt.Sprintf("%s%dC", CSI, n) }
func CursorBack(n int) string    { return fmt.Sprintf("%s%dD", CSI, n) }

// CursorNextLine/PrevLine move to the start of the line, n lines down/up.
func CursorNextLine(n int) string { return fmt.Sprintf("%s%dE", CSI, n) }
func CursorPrevLine(n int) string { return fmt.Sprintf("%s%dF", CSI, n) }

// CursorToColumn moves to an absolute column on the current line (1-based).
func CursorToColumn(n int) string { return fmt.Sprintf("%s%dG", CSI, n) }

// CursorTo moves to an absolute (row, col) position (1-based; top-left is 1,1).
func CursorTo(row, col int) string { return fmt.Sprintf("%s%d;%dH", CSI, row, col) }

const (
	CursorSave    = Esc + "7" // DECSC: save cursor position + attributes
	CursorRestore = Esc + "8" // DECRC: restore what DECSC saved

	CursorHide = CSI + "?25l"
	CursorShow = CSI + "?25h"
)

// --- Erasing ------------------------------------------------------------

// Erase in Display (ED).
const (
	EraseScreenDown = CSI + "0J" // cursor -> end of screen
	EraseScreenUp   = CSI + "1J" // start of screen -> cursor
	EraseScreen     = CSI + "2J" // whole screen
)

// Erase in Line (EL).
const (
	EraseLineEnd   = CSI + "0K" // cursor -> end of line
	EraseLineStart = CSI + "1K" // start of line -> cursor
	EraseLine      = CSI + "2K" // whole line
)

// --- SGR: colors and text styles ----------------------------------------

const (
	Reset     = CSI + "0m"
	Bold      = CSI + "1m"
	Dim       = CSI + "2m"
	Italic    = CSI + "3m"
	Underline = CSI + "4m"
	Inverse   = CSI + "7m"
)

// FG/BG select the standard 8-color foreground/background (code 0-7:
// black, red, green, yellow, blue, magenta, cyan, white).
func FG(code int) string { return fmt.Sprintf("%s%dm", CSI, 30+code) }
func BG(code int) string { return fmt.Sprintf("%s%dm", CSI, 40+code) }

// FGBright/BGBright select the bright variants of the same 8 colors.
func FGBright(code int) string { return fmt.Sprintf("%s%dm", CSI, 90+code) }
func BGBright(code int) string { return fmt.Sprintf("%s%dm", CSI, 100+code) }

// FG256/BG256 select from the 256-color palette (n = 0-255).
func FG256(n int) string { return fmt.Sprintf("%s38;5;%dm", CSI, n) }
func BG256(n int) string { return fmt.Sprintf("%s48;5;%dm", CSI, n) }

// FGRGB/BGRGB select a 24-bit "true color".
func FGRGB(r, g, b int) string { return fmt.Sprintf("%s38;2;%d;%d;%dm", CSI, r, g, b) }
func BGRGB(r, g, b int) string { return fmt.Sprintf("%s48;2;%d;%d;%dm", CSI, r, g, b) }

// --- Alternate screen buffer ---------------------------------------------
//
// What vim/less/htop use so they don't clobber your shell scrollback.

const (
	AltScreenEnter = CSI + "?1049h"
	AltScreenExit  = CSI + "?1049l"
)
