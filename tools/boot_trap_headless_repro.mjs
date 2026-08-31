#!/usr/bin/env node
// Headless-Chrome repro harness for the mailed-in boot crash — `Invalid
// argument: 0`, web release only (docs/autonomous-queue.md:110, "a boot
// crash the app cannot recover from on its own").
//
// This is step (a) named by the 2026-09-01 queue update: every VM-side
// avenue (test/boot_trap_shape_vm_repro_test.dart) is spent — 7 stale-value
// shapes through runBootstrapProper threw no ArgumentError. The one
// candidate left is web-only code (lib/services/url_sync_service_web.dart's
// _applyHashToState / _parseHash), gated `dart:js_interop` and unreachable
// from the VM harness. A browser is the missing tool, not a missing idea.
//
// What this does, against a real target origin (default: deployed dev):
//   1. Launch headless Chrome with a throwaway profile.
//   2. Load the origin once so localStorage exists for it.
//   3. Clear localStorage and plant EXACTLY the trap's three legacy keys
//      (flutter.book / flutter.chapter / flutter.version) — no profile.*
//      keys, matching the mailed-in report.
//   4. Reload with a chosen URL hash (bare `/`, a valid deep link, or a
//      stale one whose book/chapter/version disagree with the planted
//      keys — the one shape only `_applyHashToState` sees, since
//      `restoreState()` already ran before the hash is applied).
//   5. Capture window.onerror, unhandledrejection, console output and
//      CDP Runtime.exceptionThrown for ~15s, then report what happened.
//
// Zero dependencies: Node 24's built-in global `fetch` and `WebSocket`
// talk to Chrome's DevTools Protocol directly — no puppeteer, no
// node_modules, nothing added to this repo's dependency graph.
//
//     node tools/boot_trap_headless_repro.mjs [origin]
//
// Defaults to https://yswords-dev.netlify.app (dev only — never prod).
'use strict';

import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const CHROME =
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PORT = 9333;
const ORIGIN = process.argv[2] || 'https://yswords-dev.netlify.app';

if (!/yswords-dev\.netlify\.app|yswords-qat\.netlify\.app|localhost|127\.0\.0\.1/.test(ORIGIN)) {
  console.error(`Refusing: ${ORIGIN} is not a recognised dev/qat/local origin. ` +
    'This harness plants localStorage and reloads — never point it at prod.');
  process.exit(2);
}

const TRAP_SHAPES = [
  {
    name: 'bare-hash (#/ / no hash at all)',
    hash: '',
    plant: { 'flutter.book': 'John', 'flutter.chapter': '3', 'flutter.version': 'kjv' },
  },
  {
    name: 'valid-deep-link matching planted state',
    hash: '#/john/3:16?v=kjv',
    plant: { 'flutter.book': 'John', 'flutter.chapter': '3', 'flutter.version': 'kjv' },
  },
  {
    name: 'stale deep link DISAGREEING with planted state ' +
          '(the shape only _applyHashToState alone sees)',
    hash: '#/revelation/999:1?v=biblexg-v2',
    plant: { 'flutter.book': 'John', 'flutter.chapter': '3', 'flutter.version': 'kjv' },
  },
];

function waitFor(predicate, timeoutMs, intervalMs = 200) {
  const start = Date.now();
  return new Promise((resolve, reject) => {
    const tick = async () => {
      let ok;
      try {
        ok = await predicate();
      } catch {
        ok = false;
      }
      if (ok) return resolve();
      if (Date.now() - start > timeoutMs) {
        return reject(new Error('timed out waiting'));
      }
      setTimeout(tick, intervalMs);
    };
    tick();
  });
}

async function cdpVersion() {
  const res = await fetch(`http://127.0.0.1:${PORT}/json/version`);
  if (!res.ok) throw new Error(`status ${res.status}`);
  return res.json();
}

async function newTab(url) {
  const res = await fetch(
    `http://127.0.0.1:${PORT}/json/new?${encodeURIComponent(url)}`,
    { method: 'PUT' },
  );
  if (!res.ok) throw new Error(`/json/new failed: ${res.status}`);
  return res.json();
}

async function closeTab(id) {
  await fetch(`http://127.0.0.1:${PORT}/json/close/${id}`).catch(() => {});
}

class Cdp {
  constructor(wsUrl) {
    this.ws = new WebSocket(wsUrl);
    this.nextId = 1;
    this.pending = new Map();
    this.listeners = [];
    this.ready = new Promise((resolve, reject) => {
      this.ws.addEventListener('open', () => resolve());
      this.ws.addEventListener('error', (e) => reject(e));
    });
    this.ws.addEventListener('message', (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id && this.pending.has(msg.id)) {
        const { resolve, reject } = this.pending.get(msg.id);
        this.pending.delete(msg.id);
        if (msg.error) reject(new Error(JSON.stringify(msg.error)));
        else resolve(msg.result);
      } else if (msg.method) {
        for (const l of this.listeners) l(msg.method, msg.params);
      }
    });
  }

  send(method, params = {}) {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }

  on(fn) {
    this.listeners.push(fn);
  }

  close() {
    this.ws.close();
  }
}

async function runShape(shape) {
  console.log(`\n=== ${shape.name} ===`);
  console.log(`    hash: ${JSON.stringify(shape.hash) || '(empty)'}`);
  console.log(`    planted keys: ${JSON.stringify(shape.plant)}`);

  const tab = await newTab('about:blank');
  const cdp = new Cdp(tab.webSocketDebuggerUrl);
  await cdp.ready;

  const events = [];
  cdp.on((method, params) => {
    if (method === 'Runtime.exceptionThrown') {
      const d = params.exceptionDetails;
      events.push({
        kind: 'Runtime.exceptionThrown',
        text: d.text,
        message: d.exception?.description || d.exception?.value,
        url: d.url,
        line: d.lineNumber,
        col: d.columnNumber,
        stack: d.stackTrace,
      });
    } else if (method === 'Runtime.consoleAPICalled') {
      // Capture every console call regardless of type. Flutter web release
      // does not strip debugPrint, so the boot-failure prints this repro
      // exists to see (url_sync_service_web.dart's "[UrlSync] boot apply
      // failed", main.dart's "Bootstrap failed at ...") arrive as ordinary
      // console.log, not console.error — filtering at capture time would
      // silently discard exactly the evidence this harness is for.
      const args = (params.args || [])
        .map((a) => a.value ?? a.description ?? '')
        .join(' ');
      events.push({ kind: `console.${params.type}`, text: args });
    }
  });

  await cdp.send('Runtime.enable');
  await cdp.send('Page.enable');

  // Inject BEFORE any page script runs, on every document (so it survives
  // the reload after planting storage) — mirrors what a real browser
  // console would show for window.onerror / unhandledrejection, which CDP
  // does not surface as Runtime.exceptionThrown by default for onerror
  // handlers that swallow the event.
  await cdp.send('Page.addScriptToEvaluateOnNewDocument', {
    source: `
      window.addEventListener('error', function(e) {
        console.error('BOOT_TRAP window.onerror: ' + e.message +
          ' @ ' + e.filename + ':' + e.lineno + ':' + e.colno);
      });
      window.addEventListener('unhandledrejection', function(e) {
        var r = e.reason;
        console.error('BOOT_TRAP unhandledrejection: ' +
          (r && r.stack ? r.stack : String(r)));
      });
    `,
  });

  // 1. Load the bare origin first so localStorage exists for it.
  await cdp.send('Page.navigate', { url: ORIGIN + '/' });
  await waitFor(async () => {
    const r = await cdp.send('Runtime.evaluate', {
      expression: 'document.readyState',
    });
    return r.result?.value === 'complete';
  }, 15000).catch(() => {
    console.log('    (warning: initial load did not reach readyState=complete in 15s)');
  });

  // 2. Clear storage, plant exactly the trap's keys.
  const plantExpr = `
    (function() {
      localStorage.clear();
      var plant = ${JSON.stringify(shape.plant)};
      for (var k in plant) localStorage.setItem(k, plant[k]);
      return Object.keys(localStorage).sort();
    })()
  `;
  const plantResult = await cdp.send('Runtime.evaluate', {
    expression: plantExpr,
    returnByValue: true,
  });
  console.log(`    localStorage after planting: ${JSON.stringify(plantResult.result?.value)}`);

  // 3. Reload with the chosen hash present at load time (hash must be
  // part of the navigated URL — captureBootHash() in main.dart runs
  // synchronously before runApp, so setting location.hash after load
  // would miss it). A same-origin navigation that differs from the
  // current URL only in the fragment is a same-document navigation in
  // Chrome — no reload, no main(), no captureBootHash() — so bounce
  // through about:blank first to force a real document load. Same-origin
  // localStorage survives this because it's origin-scoped, not
  // document-scoped.
  await cdp.send('Page.navigate', { url: 'about:blank' });
  await waitFor(async () => {
    const r = await cdp.send('Runtime.evaluate', {
      expression: 'document.readyState',
    });
    return r.result?.value === 'complete';
  }, 5000).catch(() => {});

  const timeOriginBefore = await cdp.send('Runtime.evaluate', {
    expression: 'performance.timeOrigin',
  }).then((r) => r.result?.value).catch(() => null);

  const targetUrl = ORIGIN + '/' + shape.hash;
  await cdp.send('Page.navigate', { url: targetUrl });
  await waitFor(async () => {
    const r = await cdp.send('Runtime.evaluate', {
      expression: 'document.readyState',
    });
    return r.result?.value === 'complete';
  }, 15000).catch(() => {
    console.log('    (warning: target load did not reach readyState=complete in 15s)');
  });

  // Confirm the boot actually re-ran: a same-document navigation would
  // have a stale (unset) or unchanged performance.timeOrigin; a real
  // load gives the new document a fresh one.
  const timeOriginAfter = await cdp.send('Runtime.evaluate', {
    expression: 'performance.timeOrigin',
  }).then((r) => r.result?.value).catch(() => null);
  console.log(`    fresh document load confirmed: ` +
    `${timeOriginBefore != null && timeOriginAfter != null && timeOriginAfter !== timeOriginBefore} ` +
    `(timeOrigin ${timeOriginBefore} -> ${timeOriginAfter})`);

  // 4. Give the bundle time to boot and (maybe) crash. The mitigation
  // path is a 45s auto-recovery timer; this window is longer than the
  // minimum needed on purpose — long enough to distinguish "the engine
  // never painted" from "still loading", short of the 45s recovery
  // timer so it doesn't mask a pre-mitigation cold-boot throw.
  await new Promise((r) => setTimeout(r, 15000));

  const finalState = await cdp.send('Runtime.evaluate', {
    expression: `
      (function() {
        var el = document.getElementById('ys-boot');
        // <flt-glass-pane> is the shadow host Flutter web's engine
        // creates once it has actually painted a frame — a more
        // reliable "did it boot" signal than innerText, which stays
        // empty even on a healthy boot because Flutter renders to
        // canvas/DOM nodes that document.body.innerText does not walk.
        var glassPane = document.querySelector('flt-glass-pane');
        return {
          bootSplashPresent: !!el,
          glassPanePresent: !!glassPane,
          bodyTextSnippet: (document.body.innerText || '').slice(0, 300),
          localStorageKeys: Object.keys(localStorage).sort(),
        };
      })()
    `,
    returnByValue: true,
  }).catch((e) => ({ result: { value: { error: String(e) } } }));

  console.log(`    events captured: ${events.length}`);
  for (const e of events) {
    console.log(`      [${e.kind}] ${e.text || e.message}` +
      (e.url ? ` (${e.url}:${e.line}:${e.col})` : ''));
    if (e.stack?.callFrames?.length) {
      for (const f of e.stack.callFrames.slice(0, 5)) {
        console.log(`          at ${f.functionName || '(anonymous)'} ` +
          `${f.url}:${f.lineNumber}:${f.columnNumber}`);
      }
    }
  }
  console.log(`    final page state: ${JSON.stringify(finalState.result?.value)}`);

  cdp.close();
  await closeTab(tab.id);

  return { shape: shape.name, events, finalState: finalState.result?.value };
}

async function main() {
  const userDataDir = mkdtempSync(join(tmpdir(), 'ys-boot-trap-repro-'));
  console.log(`Launching headless Chrome (profile: ${userDataDir}) against ${ORIGIN}`);

  const chrome = spawn(CHROME, [
    '--headless=new',
    `--remote-debugging-port=${PORT}`,
    `--user-data-dir=${userDataDir}`,
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-extensions',
  ], { stdio: 'ignore' });

  const cleanup = () => {
    try { chrome.kill(); } catch {}
    try { rmSync(userDataDir, { recursive: true, force: true }); } catch {}
  };
  process.on('exit', cleanup);
  process.on('SIGINT', () => { cleanup(); process.exit(130); });

  try {
    await waitFor(() => cdpVersion().then(() => true), 10000);
  } catch (e) {
    console.error('Chrome did not come up on the debug port in 10s:', e.message);
    process.exitCode = 2;
    return;
  }

  const results = [];
  for (const shape of TRAP_SHAPES) {
    try {
      results.push(await runShape(shape));
    } catch (e) {
      console.error(`  FAILED to run shape "${shape.name}": ${e.stack || e}`);
      results.push({ shape: shape.name, error: String(e) });
    }
  }

  console.log('\n=== summary ===');
  let anyThrow = false;
  for (const r of results) {
    const throwCount = (r.events || []).filter(
      (e) => e.kind === 'Runtime.exceptionThrown' ||
             /BOOT_TRAP window\.onerror|BOOT_TRAP unhandledrejection/i.test(e.text || ''),
    ).length;
    if (throwCount > 0) anyThrow = true;
    console.log(`  ${r.shape}: ${throwCount} throw-like event(s)` +
      (r.error ? ` (harness error: ${r.error})` : ''));
  }
  console.log(anyThrow
    ? '\nAt least one shape produced a throw/rejection — see events above ' +
      'for the frame. Do NOT state a root cause without decoding it ' +
      'against a matching --source-maps build; report only what was ' +
      'observed here.'
    : '\nNo shape reproduced a throw or unhandled rejection in the ~15s ' +
      'observation window. This does not clear _applyHashToState / ' +
      '_parseHash beyond the exact shapes tried — see the shapes list ' +
      'above for exactly what that is.');
}

main();
