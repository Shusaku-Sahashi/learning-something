'use strict';

/**
 * 06 - Suggest box (the payoff example).
 *
 * Run: node examples/06-suggest-box.js
 *
 * This is the pattern behind the kind of terminal autocomplete dropdown
 * IRIS (https://github.com/versenilvis/IRIS) and similar tools draw: a
 * text input with a live-filtered list of suggestions rendered directly
 * below it, redrawn on every keystroke without disturbing the rest of the
 * terminal.
 *
 * The building blocks, all from lib/ansi.js:
 *   - raw mode stdin, so keys are delivered one at a time instead of only
 *     after the user presses Enter (that part is Node's job, not ANSI's)
 *   - cursor.toColumn(1) + erase.line   -> redraw a single line in place
 *   - cursor.down(n) / cursor.up(n)     -> move between the input line and
 *                                           the suggestion lines below it
 *   - style.inverse                     -> highlight the selected suggestion
 *
 * Controls: type to filter, Up/Down to move the selection, Enter to
 * accept, Esc or Ctrl+C to quit.
 */

const { cursor, erase, style } = require('../lib/ansi');

const WORDS = [
  'apple', 'apricot', 'avocado', 'banana', 'blackberry', 'blueberry',
  'cherry', 'coconut', 'cranberry', 'date', 'dragonfruit', 'fig',
  'grape', 'grapefruit', 'guava', 'kiwi', 'lemon', 'lime', 'lychee',
  'mango', 'melon', 'nectarine', 'orange', 'papaya', 'passionfruit',
  'peach', 'pear', 'persimmon', 'pineapple', 'plum', 'pomegranate',
  'raspberry', 'strawberry', 'tangerine', 'watermelon',
];

const MAX_SUGGESTIONS = 5;
const PROMPT = '? ';

// Key codes we care about, spelled out with \u escapes so nothing here
// depends on invisible bytes surviving a copy/paste.
const KEY_CTRL_C = '';
const KEY_ESC = '';
const KEY_BACKSPACE_1 = '';
const KEY_BACKSPACE_2 = '\b';
const KEY_UP = '[A';
const KEY_DOWN = '[B';

if (!process.stdin.isTTY) {
  console.error('This demo needs an interactive terminal (a TTY) to run.');
  process.exit(1);
}

let input = '';
let selected = 0;

function matches() {
  if (!input) return [];
  const needle = input.toLowerCase();
  return WORDS.filter((w) => w.startsWith(needle)).slice(0, MAX_SUGGESTIONS);
}

function redraw() {
  const list = matches();
  if (selected >= list.length) selected = Math.max(0, list.length - 1);

  // Redraw the input line in place.
  process.stdout.write(cursor.toColumn(1) + erase.line);
  process.stdout.write(`${style.bold}${PROMPT}${style.reset}${input}`);

  // Redraw each suggestion slot below it, blank or highlighted.
  for (let i = 0; i < MAX_SUGGESTIONS; i++) {
    process.stdout.write(cursor.down(1) + cursor.toColumn(1) + erase.line);
    const word = list[i];
    if (word) {
      process.stdout.write(
        i === selected ? `${style.inverse}> ${word}${style.reset}` : `  ${word}`
      );
    }
  }

  // Hop back up to the input line and put the text cursor right after
  // whatever the user has typed so far.
  process.stdout.write(cursor.up(MAX_SUGGESTIONS));
  process.stdout.write(cursor.toColumn(PROMPT.length + input.length + 1));
}

function cleanup(finalMessage) {
  process.stdout.write(cursor.down(MAX_SUGGESTIONS) + cursor.toColumn(1));
  process.stdout.write(cursor.show);
  process.stdin.setRawMode(false);
  process.stdin.pause();
  if (finalMessage) console.log(finalMessage);
  process.exit(0);
}

console.log('Type a fruit name. Up/Down to select, Enter to accept, Esc/Ctrl+C to quit.\n');

// Reserve the input line + suggestion lines in the terminal buffer before
// we start moving the cursor around, so redraw() never has to worry about
// scrolling mid-frame.
process.stdout.write('\r\n'.repeat(MAX_SUGGESTIONS));
process.stdout.write(cursor.up(MAX_SUGGESTIONS));
process.stdout.write(cursor.hide);
redraw();

process.stdin.setRawMode(true);
process.stdin.resume();
process.stdin.setEncoding('utf8');

// A single `data` event is NOT guaranteed to contain exactly one keypress.
// If you type fast (or something pastes text), the kernel can hand Node
// several bytes at once, e.g. "ban" arrives as one 3-byte chunk instead of
// three separate events. So we walk the chunk ourselves and pull out one
// logical key at a time (a control byte, a 3-byte arrow sequence, or a
// single printable character) instead of assuming chunk === one key.
function handleKey(key) {
  const list = matches();

  if (key === KEY_CTRL_C) {
    cleanup();
    return;
  }
  if (key === KEY_ESC) {
    // A lone ESC byte (not the start of an arrow-key sequence).
    cleanup('Cancelled.');
    return;
  }
  if (key === KEY_UP) {
    selected = Math.max(0, selected - 1);
    redraw();
    return;
  }
  if (key === KEY_DOWN) {
    selected = Math.min(list.length - 1, selected + 1);
    redraw();
    return;
  }
  if (key === '\r' || key === '\n') {
    // Enter
    if (list[selected]) input = list[selected];
    redraw();
    cleanup(`Selected: ${input}`);
    return;
  }
  if (key === KEY_BACKSPACE_1 || key === KEY_BACKSPACE_2) {
    input = input.slice(0, -1);
    selected = 0;
    redraw();
    return;
  }
  if (key.length === 1 && key >= ' ') {
    // A regular printable character.
    input += key;
    selected = 0;
    redraw();
  }
}

process.stdin.on('data', (chunk) => {
  let i = 0;
  while (i < chunk.length) {
    if (chunk[i] === '') {
      const arrowSeq = chunk.slice(i, i + 3);
      if (arrowSeq === KEY_UP || arrowSeq === KEY_DOWN) {
        handleKey(arrowSeq);
        i += 3;
        continue;
      }
      handleKey(KEY_ESC);
      i += 1;
      continue;
    }
    handleKey(chunk[i]);
    i += 1;
  }
});
