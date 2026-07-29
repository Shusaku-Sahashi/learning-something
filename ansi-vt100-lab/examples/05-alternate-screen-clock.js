'use strict';

/**
 * 05 - The alternate screen buffer.
 *
 * Run: node examples/05-alternate-screen-clock.js  (Ctrl+C to quit)
 *
 * Full-screen tools like vim, less, htop, and fzf don't want to spam your
 * shell's scrollback history. Instead they switch to a second, separate
 * screen buffer (ESC[?1049h), draw whatever they want on it, and then
 * switch back (ESC[?1049l) when they exit - at which point your terminal
 * looks exactly like it did before the program ran.
 */

const { cursor, erase, style, altScreen } = require('../lib/ansi');

function frame() {
  const now = new Date().toLocaleTimeString();
  process.stdout.write(cursor.to(1, 1));
  process.stdout.write(erase.screen);
  process.stdout.write(cursor.to(3, 4));
  process.stdout.write(`${style.bold}${style.fg(6)}ANSI alternate-screen demo${style.reset}`);
  process.stdout.write(cursor.to(5, 4));
  process.stdout.write(`Current time: ${style.fgBright(3)}${now}${style.reset}`);
  process.stdout.write(cursor.to(7, 4));
  process.stdout.write('Press Ctrl+C to return to your normal shell screen.');
}

process.stdout.write(altScreen.enter);
process.stdout.write(cursor.hide);

const timer = setInterval(frame, 250);
frame();

function cleanup() {
  clearInterval(timer);
  process.stdout.write(cursor.show);
  // Leaving the alternate screen restores whatever was on screen before
  // this program started - none of the clock frames end up in scrollback.
  process.stdout.write(altScreen.exit);
  process.exit(0);
}

process.on('SIGINT', cleanup);
