'use strict';

/**
 * 04 - Erasing + in-place updates (a progress bar).
 *
 * Run: node examples/04-erase-and-progress-bar.js
 *
 * The trick behind every "redraws in place" CLI tool (progress bars,
 * spinners, live-updating counters) is:
 *   1. "\r"          - carriage return, move cursor to column 1 (no newline)
 *   2. erase.lineEnd  - clear everything from the cursor to the end of line
 *   3. write the new frame
 *
 * Without step 2, leftover characters from a longer previous frame would
 * stick around after the line gets shorter.
 */

const { erase, style } = require('../lib/ansi');

const TOTAL = 40;
let progress = 0;

function render() {
  const filled = Math.round((progress / TOTAL) * 30);
  const bar = '#'.repeat(filled) + '-'.repeat(30 - filled);
  const pct = Math.round((progress / TOTAL) * 100)
    .toString()
    .padStart(3, ' ');

  // "\r" + erase.lineEnd is the redraw idiom. style.fg(2) is green.
  process.stdout.write(`\r${erase.lineEnd}[${style.fg(2)}${bar}${style.reset}] ${pct}%`);
}

const timer = setInterval(() => {
  progress++;
  render();
  if (progress >= TOTAL) {
    clearInterval(timer);
    process.stdout.write('\n');
    console.log('Done!');
  }
}, 100);
