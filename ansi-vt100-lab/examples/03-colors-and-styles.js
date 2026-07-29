'use strict';

/**
 * 03 - Colors and text styles (SGR).
 *
 * Run: node examples/03-colors-and-styles.js
 *
 * Walks through the three color systems terminals commonly support:
 *   1. 16 colors   (ESC[30-37m / ESC[90-97m)  - supported almost everywhere
 *   2. 256 colors  (ESC[38;5;<n>m)            - most modern terminals
 *   3. true color  (ESC[38;2;r;g;bm)          - most modern terminals
 * plus a few text styles (bold, underline, etc).
 */

const { style } = require('../lib/ansi');

console.log('--- 16-color palette (foreground) ---');
const names = ['black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white'];
let line = '';
names.forEach((name, i) => {
  line += `${style.fg(i)}${name.padEnd(8)}${style.reset}`;
});
console.log(line);

let brightLine = '';
names.forEach((name, i) => {
  brightLine += `${style.fgBright(i)}${('bright-' + name).padEnd(14)}${style.reset}`;
});
console.log(brightLine);

console.log('\n--- Text styles ---');
console.log(`${style.bold}bold${style.reset}  ${style.dim}dim${style.reset}  ${style.italic}italic${style.reset}  ${style.underline}underline${style.reset}  ${style.inverse}inverse${style.reset}`);

console.log('\n--- 256-color cube (a slice of it) ---');
let cube = '';
for (let n = 16; n < 52; n++) {
  cube += `${style.bg256(n)}  ${style.reset}`;
}
console.log(cube);

console.log('\n--- True color (24-bit) gradient ---');
let gradient = '';
const steps = 40;
for (let i = 0; i < steps; i++) {
  const r = Math.round((i / steps) * 255);
  const g = Math.round(((steps - i) / steps) * 255);
  const b = 128;
  gradient += `${style.bgRgb(r, g, b)} ${style.reset}`;
}
console.log(gradient);

console.log(
  '\nNote: true-color and 256-color support depends on your terminal & the\n' +
    'COLORTERM/TERM environment variables. If the gradient above looks\n' +
    "banded instead of smooth, your terminal probably doesn't support 24-bit color."
);
