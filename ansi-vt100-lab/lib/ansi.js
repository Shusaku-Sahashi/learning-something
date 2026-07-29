'use strict';

/**
 * Minimal ANSI / VT100 escape sequence toolkit.
 *
 * Every terminal escape sequence starts with the ESC character (0x1B, "\x1b").
 * Most of the sequences we care about are "CSI" (Control Sequence Introducer)
 * sequences, which look like: ESC [ <params> <final-byte>
 *
 *   \x1b[   <- CSI
 *   31      <- parameter(s), e.g. "31" = red foreground
 *   m       <- final byte, "m" means "SGR: Select Graphic Rendition"
 *
 * This file has no dependencies on purpose: everything here is a plain
 * string built by hand, so you can see exactly what bytes are being sent
 * to the terminal. Real projects would reach for a library like `chalk`
 * or `ansi-escapes`, but the point of this lab is to understand what
 * those libraries do under the hood.
 */

const ESC = '\x1b';
const CSI = `${ESC}[`;

// ---------------------------------------------------------------------------
// Cursor movement
// ---------------------------------------------------------------------------

const cursor = {
  up: (n = 1) => `${CSI}${n}A`,
  down: (n = 1) => `${CSI}${n}B`,
  forward: (n = 1) => `${CSI}${n}C`,
  back: (n = 1) => `${CSI}${n}D`,

  // Move cursor to the start of the line, n lines down/up.
  nextLine: (n = 1) => `${CSI}${n}E`,
  prevLine: (n = 1) => `${CSI}${n}F`,

  // Move to an absolute column on the current line (1-based).
  toColumn: (n = 1) => `${CSI}${n}G`,

  // Move to an absolute (row, column) position (1-based, top-left is 1,1).
  to: (row = 1, col = 1) => `${CSI}${row};${col}H`,

  save: `${ESC}7`, // DECSC: save cursor position + attributes
  restore: `${ESC}8`, // DECRC: restore what DECSC saved

  hide: `${CSI}?25l`,
  show: `${CSI}?25h`,
};

// ---------------------------------------------------------------------------
// Erasing
// ---------------------------------------------------------------------------

const erase = {
  // Erase in Display (ED): 0 = cursor->end, 1 = start->cursor, 2 = whole screen
  screenDown: `${CSI}0J`,
  screenUp: `${CSI}1J`,
  screen: `${CSI}2J`,

  // Erase in Line (EL): 0 = cursor->end, 1 = start->cursor, 2 = whole line
  lineEnd: `${CSI}0K`,
  lineStart: `${CSI}1K`,
  line: `${CSI}2K`,
};

// ---------------------------------------------------------------------------
// SGR (Select Graphic Rendition) - colors and text styles
// ---------------------------------------------------------------------------

const style = {
  reset: `${CSI}0m`,
  bold: `${CSI}1m`,
  dim: `${CSI}2m`,
  italic: `${CSI}3m`,
  underline: `${CSI}4m`,
  inverse: `${CSI}7m`,

  // Standard 8/16-color foreground/background (30-37, 90-97 / 40-47, 100-107)
  fg: (code) => `${CSI}${30 + code}m`,
  bg: (code) => `${CSI}${40 + code}m`,
  fgBright: (code) => `${CSI}${90 + code}m`,
  bgBright: (code) => `${CSI}${100 + code}m`,

  // 256-color palette: ESC[38;5;<n>m (fg) / ESC[48;5;<n>m (bg), n = 0-255
  fg256: (n) => `${CSI}38;5;${n}m`,
  bg256: (n) => `${CSI}48;5;${n}m`,

  // 24-bit "true color": ESC[38;2;<r>;<g>;<b>m
  fgRgb: (r, g, b) => `${CSI}38;2;${r};${g};${b}m`,
  bgRgb: (r, g, b) => `${CSI}48;2;${r};${g};${b}m`,
};

// ---------------------------------------------------------------------------
// Alternate screen buffer (what vim/less/htop use so they don't clobber
// your shell scrollback)
// ---------------------------------------------------------------------------

const altScreen = {
  enter: `${CSI}?1049h`,
  exit: `${CSI}?1049l`,
};

module.exports = { ESC, CSI, cursor, erase, style, altScreen };
