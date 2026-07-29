'use strict';

/**
 * 02 - Cursor movement.
 *
 * Run: node examples/02-cursor-movement.js
 *
 * Bounces a "*" around inside a small box using absolute cursor
 * positioning (CUP: ESC[<row>;<col>H). This is the same primitive that
 * lets TUIs draw things anywhere on screen instead of only appending to
 * the bottom, like a normal console.log would.
 */

const { cursor, erase, style } = require('../lib/ansi');

const WIDTH = 20;
const HEIGHT = 8;
const originRow = 3; // leave a couple of lines at the top for instructions

function drawBox() {
  console.log('Bouncing cursor demo - Ctrl+C to quit\n');
  for (let r = 0; r < HEIGHT; r++) {
    console.log('#' + ' '.repeat(WIDTH) + '#');
  }
  console.log('#' + '#'.repeat(WIDTH + 2));
}

function moveTo(row, col) {
  process.stdout.write(cursor.to(originRow + row, col + 2));
}

drawBox();
process.stdout.write(cursor.hide);

let x = 0;
let y = 0;
let dx = 1;
let dy = 1;

const timer = setInterval(() => {
  // Erase the previous position by overwriting it with a space.
  moveTo(y, x);
  process.stdout.write(' ');

  x += dx;
  y += dy;
  if (x <= 0 || x >= WIDTH - 1) dx *= -1;
  if (y <= 0 || y >= HEIGHT - 1) dy *= -1;

  moveTo(y, x);
  process.stdout.write(`${style.fgBright(3)}*${style.reset}`);

  // Park the real cursor below the box so it doesn't sit on top of the "*".
  process.stdout.write(cursor.to(originRow + HEIGHT + 2, 1));
}, 80);

function cleanup() {
  clearInterval(timer);
  process.stdout.write(cursor.show);
  process.stdout.write('\n');
  process.exit(0);
}

process.on('SIGINT', cleanup);
