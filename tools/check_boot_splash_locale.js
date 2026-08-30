#!/usr/bin/env node
// Exercises the boot splash's locale resolution against the REAL source
// in web/index.html — the function is extracted from the page and run,
// not re-implemented here, so this cannot drift from what ships.
//
// Why a node script and not a Dart test: the logic is browser JavaScript
// living in an HTML file. A Dart test can assert the text is present; it
// cannot tell you that `zh-TW` resolves to 雅偉之言. Run it directly:
//
//     node tools/check_boot_splash_locale.js
//
// CI runs it too — see .github/workflows/flutter-ci.yml.
//
// TRAP, paid for on 2026-08-30: the first version of this harness set
// `global.navigator = {language: 'zh-CN'}` and reported five failures
// that were not real. Node 21+ ships a built-in `navigator`; the
// assignment reports `writable: true` and then does nothing, so every
// case fell through to the host's own `en-US`. `vm.runInNewContext` with
// an explicit sandbox is the only way to actually control these globals.
// A harness that fails for the wrong reason is as dangerous as one that
// passes for the wrong reason.
'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const htmlPath = path.join(__dirname, '..', 'web', 'index.html');
const html = fs.readFileSync(htmlPath, 'utf8');

const fnMatch = html.match(/(function ysAppLocale\(\) \{[\s\S]*?\n {6}\})/);
if (!fnMatch) {
  console.error('FATAL: could not find ysAppLocale() in web/index.html.');
  console.error('The boot splash locale logic was renamed or removed.');
  process.exit(2);
}
const src = fnMatch[1] + '\nysAppLocale();';

// Mirrors the NAMES map in the page. Kept here deliberately rather than
// extracted: if the page's names change without this file changing, the
// expectations below should have to be revisited by a human.
const NAMES = {
  'zh-Hans': '雅伟之言',
  'zh-Hant': '雅偉之言',
  en: "Yahweh's Words",
};

const cases = [
  // The app's stored preference wins over the browser's guess. This is
  // the case that matters most and the one a browser-language-only
  // implementation gets wrong: measured on the author's machine,
  // navigator.language was en-US while the app was set to zh-Hans.
  ['app zh-Hans / browser en-US', { 'flutter.locale': '"zh-Hans"' }, 'en-US', 'zh-Hans'],
  ['app zh-Hant / browser en-US', { 'flutter.locale': '"zh-Hant"' }, 'en-US', 'zh-Hant'],
  ['app en / browser zh-CN', { 'flutter.locale': '"en"' }, 'zh-CN', 'en'],

  // shared_preferences stores strings JSON-encoded, so the value arrives
  // with literal quotes. A bare === would fall through to the browser
  // guess, which usually agrees — silently correct in testing, wrong for
  // exactly the users who changed the app's language.
  ['legacy unquoted value', { 'flutter.locale': 'zh-Hant' }, 'en-US', 'zh-Hant'],
  ['garbage in storage falls back', { 'flutter.locale': '"klingon"' }, 'zh-TW', 'zh-Hant'],

  // Fallback path mirrors AppSettings._detectSystemLocale.
  ['no storage / zh-CN', {}, 'zh-CN', 'zh-Hans'],
  ['no storage / zh-TW', {}, 'zh-TW', 'zh-Hant'],
  ['no storage / zh-HK', {}, 'zh-HK', 'zh-Hant'],
  ['no storage / zh-Hant-HK', {}, 'zh-Hant-HK', 'zh-Hant'],
  ['no storage / en-AU', {}, 'en-AU', 'en'],
  ['empty navigator.language', {}, '', 'en'],

  // Private mode and enterprise policy both make localStorage throw on
  // access rather than return null.
  ['storage throws / zh-CN', 'THROW', 'zh-CN', 'zh-Hans'],
];

let failed = 0;
for (const [desc, store, lang, want] of cases) {
  const sandbox = {
    window: {
      localStorage: {
        getItem(k) {
          if (store === 'THROW') throw new Error('storage blocked');
          return Object.prototype.hasOwnProperty.call(store, k) ? store[k] : null;
        },
      },
    },
    navigator: { language: lang },
  };
  const got = vm.runInNewContext(src, sandbox);
  const ok = got === want;
  if (!ok) failed++;
  const name = NAMES[got] || '(no name for this locale!)';
  console.log(
    `${ok ? 'PASS' : 'FAIL'}  ${desc.padEnd(30)} -> ${String(got).padEnd(8)} ${name}` +
      (ok ? '' : `   WANT ${want}`)
  );
}

if (failed) {
  console.error(`\n${failed} of ${cases.length} boot-splash locale cases FAILED`);
  process.exit(1);
}
console.log(`\nall ${cases.length} boot-splash locale cases passed`);
