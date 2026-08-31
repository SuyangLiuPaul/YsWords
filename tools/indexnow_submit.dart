// Tell IndexNow about every prerendered page, in one request.
//
//     dart run tools/indexnow_submit.dart            # dry run, prints only
//     dart run tools/indexnow_submit.dart --send     # actually POSTs
//
// ── Why ───────────────────────────────────────────────────────────────
// A sitemap is an invitation: the crawler reads it when it gets around
// to it. Measured 2026-08-31, hours after `/sitemap.xml` was accepted by
// Search Console, five of its six children still had no `Last read` at
// all. IndexNow is a push instead — one POST naming the URLs that
// changed, which Bing, Yandex, Naver and Seznam all consume (Google does
// not participate). Their own FAQ is blunt about what it buys: the URLs
// still cost crawl quota, but "search engines will generally prioritize
// crawling these URLs versus other URLs they know."
//
// For a brand-new domain with no inbound links — which is exactly what
// yahwehword.com is — that prioritisation is the whole point. Nothing
// else about the site tells a crawler these 4,346 pages are worth its
// time.
//
// ── The key ───────────────────────────────────────────────────────────
// Ownership is proven by hosting `<key>.txt` at the site root,
// containing the key and nothing else. It is NOT a secret — the entire
// mechanism depends on it being publicly readable, the same way the
// Search Console meta tag is. `web/7cad63f32387c0af0b842b4015fb2636.txt`
// ships with every deploy; `test/indexnow_test.dart` fails if the file
// ever stops matching its own name — a corruption the API answers with
// a bare 403 and no message. Note that 403 is not proof of a bad key:
// see the retry loop in main() for the propagation case measured on
// 2026-08-31.
//
// ── What it submits ───────────────────────────────────────────────────
// The live sitemaps, fetched from prod rather than read from a local
// build. Submitting what a local build *would* contain is a way to
// announce URLs that are not actually deployed yet; the whole protocol
// is a promise that these URLs are there NOW, and a 404 on a URL you
// pushed is worse than never pushing it.

import 'dart:convert';
import 'dart:io';

const kHost = 'yahwehword.com';
const kBase = 'https://$kHost';
const kKey = '7cad63f32387c0af0b842b4015fb2636';

/// Mirrors `prerenderVersions` in tools/prerender_bible.dart plus the
/// static home child. Kept as a literal rather than imported: this
/// script talks to the LIVE site, and the live sitemap index is the
/// authority on what exists there, not the local source tree. A test
/// pins the two lists to each other.
const kSitemaps = <String>[
  'sitemap-home.xml',
  'sitemap-kjv.xml',
  'sitemap-cuvs-yhwh.xml',
  'sitemap-cuvs-yhwh-tr.xml',
  'sitemap-biblexg-v2.xml',
  'sitemap-biblexg-v2-tr.xml',
];

/// IndexNow accepts up to 10,000 urls per request. Batching well under
/// that keeps a single failure from costing the whole submission, and
/// keeps each request small enough to read in a log.
const kBatch = 2000;

/// How many times a 403 is retried before it is believed. Three tries at
/// 15/30/45s covers the propagation window seen on 2026-08-31 (the very
/// next attempt already succeeded) without turning a genuinely bad key
/// into a two-minute wait for nothing.
const _kRetries = 3;

final _loc = RegExp(r'<loc>\s*([^<\s]+)\s*</loc>');

Future<List<String>> _fetchSitemap(HttpClient client, String name) async {
  final req = await client.getUrl(Uri.parse('$kBase/$name'));
  final res = await req.close();
  if (res.statusCode != 200) {
    throw StateError('$name returned ${res.statusCode} — is it deployed?');
  }
  final body = await res.transform(utf8.decoder).join();
  return _loc.allMatches(body).map((m) => m.group(1)!).toList();
}

Future<int> _submit(HttpClient client, List<String> urls) async {
  final payload = jsonEncode({
    'host': kHost,
    'key': kKey,
    'keyLocation': '$kBase/$kKey.txt',
    'urlList': urls,
  });
  final req = await client.postUrl(Uri.parse('https://api.indexnow.org/indexnow'));
  req.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
  req.write(payload);
  final res = await req.close();
  await res.drain<void>();
  return res.statusCode;
}

Future<void> main(List<String> args) async {
  final send = args.contains('--send');
  final client = HttpClient();

  // The key file has to be reachable BEFORE the submission, or every
  // batch comes back 403 with no other explanation. Checking first turns
  // "403 Forbidden" into a sentence that says what to do.
  final keyReq = await client.getUrl(Uri.parse('$kBase/$kKey.txt'));
  final keyRes = await keyReq.close();
  final keyBody = (await keyRes.transform(utf8.decoder).join()).trim();
  if (keyRes.statusCode != 200 || keyBody != kKey) {
    stderr.writeln('FATAL: $kBase/$kKey.txt is not serving the key.\n'
        '  status ${keyRes.statusCode}, body "${keyBody.length > 60 ? '${keyBody.substring(0, 60)}…' : keyBody}"\n'
        '  It ships in web/, so this means the current prod deploy '
        'predates it. Deploy first, then re-run.');
    client.close();
    exit(1);
  }
  stdout.writeln('key file verified at $kBase/$kKey.txt');

  final urls = <String>{};
  for (final name in kSitemaps) {
    final found = await _fetchSitemap(client, name);
    urls.addAll(found);
    stdout.writeln('  $name — ${found.length} urls');
  }
  final list = urls.toList()..sort();
  stdout.writeln('${list.length} distinct urls');

  if (!send) {
    stdout.writeln('\nDRY RUN — nothing submitted. Re-run with --send.');
    client.close();
    return;
  }

  for (var i = 0; i < list.length; i += kBatch) {
    final batch = list.sublist(i, (i + kBatch).clamp(0, list.length));
    var code = await _submit(client, batch);
    // 403 does NOT reliably mean the key is wrong. Measured 2026-08-31,
    // minutes after the key file first went live: the pre-flight above
    // fetched it successfully, `curl` returned 200/text-plain to every
    // user-agent, single-url and 2000-url submissions both returned 200
    // when retried moments later — yet the first real batch came back
    // 403. The endpoint validates ownership on its own schedule, and
    // right after a deploy it can still be holding a stale answer.
    //
    // So a 403 here is retried rather than treated as fatal. Only a
    // 403 that survives the backoff is reported as a key problem; the
    // other codes are genuinely about the request and fail fast.
    for (var attempt = 1; attempt <= _kRetries && code == 403; attempt++) {
      final wait = Duration(seconds: 15 * attempt);
      stdout.writeln('batch ${i ~/ kBatch + 1}: HTTP 403 — the key file '
          'verified, so this may be ownership propagation. Retry '
          '$attempt/$_kRetries in ${wait.inSeconds}s.');
      await Future<void>.delayed(wait);
      code = await _submit(client, batch);
    }
    final ok = code == 200 || code == 202;
    stdout.writeln('batch ${i ~/ kBatch + 1}: ${batch.length} urls → HTTP $code'
        '${ok ? '' : '  ← 400 bad format · 403 key still refused after '
            'retries · 422 url not on this host · 429 rate limited'}');
    if (!ok) {
      client.close();
      exit(1);
    }
  }
  stdout.writeln('\nSubmitted. IndexNow is a notification, not an '
      'indexing guarantee — check Bing Webmaster Tools → IndexNow for '
      'what it actually picked up.');
  client.close();
}
