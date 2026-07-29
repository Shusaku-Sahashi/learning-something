'use strict';

/**
 * 01 - Hello, escape sequence.
 *
 * Run: node examples/01-hello-escape.js
 *
 * This example deliberately does NOT use lib/ansi.js, so you can see the
 * raw bytes. "\x1b" is the ESC character; everything after it up to the
 * letter "m" is a Select Graphic Rendition (SGR) instruction.
 */

const ESC = '\x1b';

// \x1b[31m -> set foreground color to red (code 31)
// \x1b[0m  -> reset all styles back to default
console.log(`${ESC}[31mThis text is red.${ESC}[0m`);

// You can combine multiple SGR params separated by ";".
// 1 = bold, 32 = green foreground
console.log(`${ESC}[1;32mThis text is bold and green.${ESC}[0m`);

// 4 = underline, 34 = blue foreground
console.log(`${ESC}[4;34mThis text is underlined and blue.${ESC}[0m`);

// If your terminal doesn't understand a sequence, it usually just ignores
// it silently. Try piping this script's output through `cat -v` to see the
// escape codes as literal text instead of them being interpreted:
//
//   node examples/01-hello-escape.js | cat -v
//
// You'll see things like "^[[31m" - "^[" is how `cat -v` displays ESC (0x1B).
console.log('\nTip: pipe this through `cat -v` to see the raw escape codes.');
