#!/usr/bin/env node
// Exercises the boot splash's AUTOMATIC RECOVERY decision against the
// REAL source in web/index.html — the function is extracted from the
// page and run, not re-implemented here, so this cannot drift from what
// ships. Same approach, and the same reasoning, as
// tools/check_boot_splash_locale.js.
//
//     node tools/check_boot_autorecover.js
//
// CI runs it too — see .github/workflows/flutter-ci.yml.
//
// Why this one is worth a harness of its own: the function decides
// whether to throw away an in-flight 10 MB download. Get it wrong in the
// permissive direction and a slow phone reloads forever, each attempt
// discarding the bytes of the last — strictly worse the worse the
// connection, and invisible to anyone testing on a fast link. Get it
// wrong in the strict direction and the user stares at a dead splash,
// which is the bug it exists to fix. The false-positive side is the
// dangerous one, so most of the cases below are "must NOT recover".
//
// The Node 21 `navigator` trap that check_boot_splash_locale.js
// documents does not apply here — this function takes plain state — but
// vm.runInNewContext is used anyway to keep the two harnesses alike.
'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const htmlPath = path.join(__dirname, '..', 'web', 'index.html');
const html = fs.readFileSync(htmlPath, 'utf8');

const fnMatch = html.match(
  /(function ysShouldAutoRecover\(s\) \{[\s\S]*?\n {6}\})/);
if (!fnMatch) {
  console.error('FATAL: could not find ysShouldAutoRecover() in web/index.html.');
  console.error('The boot auto-recovery decision was renamed or removed.');
  process.exit(2);
}

const sandbox = {};
vm.createContext(sandbox);
vm.runInNewContext(fnMatch[1], sandbox);

// A load that is going fine: nothing has gone wrong and the bundle is
// still on its way.
const base = {
  booted: false,
  alreadyTried: false,
  elapsedMs: 30000,
  sawScriptError: false,
  bundleScriptFailed: false,
  mainBundleDoneMs: null,
};

const cases = [
  // ── must NOT recover ────────────────────────────────────────────
  {
    want: false,
    why: 'the app booted',
    state: { booted: true, sawScriptError: true, mainBundleDoneMs: 1000 },
  },
  {
    want: false,
    why: 'STILL DOWNLOADING on a slow link — the case that must never ' +
         'be touched, however long it has been',
    state: { elapsedMs: 300000, mainBundleDoneMs: null },
  },
  {
    want: false,
    why: 'inside the 20s floor, even though the bundle already failed',
    state: { elapsedMs: 5000, bundleScriptFailed: true },
  },
  {
    want: false,
    why: 'AN UNRELATED SCRIPT ERROR WHILE THE BUNDLE IS STILL COMING — ' +
         'the false positive that would abort a download in flight',
    state: { elapsedMs: 120000, sawScriptError: true, mainBundleDoneMs: null },
  },
  {
    want: false,
    why: 'a failed image or font is not a reason (the listener never ' +
         'sets either flag for one, so this is the state it produces)',
    state: { elapsedMs: 120000, mainBundleDoneMs: null },
  },
  {
    want: false,
    why: 'inside the 20s floor, bundle done and not yet painted',
    state: { elapsedMs: 19999, mainBundleDoneMs: 1000 },
  },
  {
    want: false,
    why: 'this tab already tried once — never loop',
    state: { alreadyTried: true, sawScriptError: true },
  },
  {
    want: false,
    why: 'storage unreadable, so alreadyTried fails CLOSED',
    state: { alreadyTried: true, elapsedMs: 600000, mainBundleDoneMs: 1000 },
  },
  {
    want: false,
    why: 'the bundle finished only moments ago — give it time to paint',
    state: { elapsedMs: 30000, mainBundleDoneMs: 25000 },
  },
  {
    want: false,
    why: 'exactly at the paint grace period, not past it',
    state: { elapsedMs: 30000, mainBundleDoneMs: 18001 },
  },

  // ── must recover ────────────────────────────────────────────────
  {
    want: true,
    why: 'the bundle arrived and threw — the bytes are in, nothing is ' +
         'in flight to interrupt',
    state: { elapsedMs: 20000, sawScriptError: true, mainBundleDoneMs: 9000 },
  },
  {
    want: true,
    why: 'the bundle script itself failed to fetch — the one signal ' +
         'allowed past the still-downloading guard',
    state: { elapsedMs: 20000, bundleScriptFailed: true, mainBundleDoneMs: null },
  },
  {
    want: true,
    why: 'the bundle arrived and never painted',
    state: { elapsedMs: 30000, mainBundleDoneMs: 18000 },
  },
  {
    want: true,
    why: 'long-parked page: bundle done, nothing on screen',
    state: { elapsedMs: 90000, mainBundleDoneMs: 8000 },
  },
];

let failures = 0;
for (const c of cases) {
  const state = Object.assign({}, base, c.state);
  const got = sandbox.ysShouldAutoRecover(state);
  const ok = got === c.want;
  if (!ok) failures++;
  console.log(
    `${ok ? 'ok  ' : 'FAIL'}  recover=${String(got).padEnd(5)} ` +
    `want=${String(c.want).padEnd(5)}  ${c.why}`);
  if (!ok) console.log(`        state: ${JSON.stringify(state)}`);
}

if (failures) {
  console.error(`\n${failures} boot auto-recovery case(s) failed.`);
  process.exit(1);
}
console.log(`\nAll ${cases.length} boot auto-recovery cases passed.`);
