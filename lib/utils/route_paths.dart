/// URL-routing Stage 4 (`docs/url-routing-plan.md` §6 batch 2): the
/// shared registered-route matcher.
///
/// Through Stage 3, every registered path was a literal string and a
/// plain `Set<String>.contains()` check was enough — `_knownRoutes` in
/// `url_sync_service_web.dart` and `_registeredRoutePaths` in
/// `app_nav.dart` each kept their own copy. Stage 4 adds the first
/// PARAMETERIZED route, `/sermons/:id`: a concrete pushed path like
/// `/sermons/004` is a member of neither set, so `.contains()` can
/// never recognise it. [matchesRegisteredRoute] replaces the bare
/// `.contains()` call at every site that needs to answer "is this path
/// one the app registered", literal or templated.
///
/// [kRegisteredRoutePaths] is the single source of truth for what
/// `main.dart`'s `_registeredGetPages` and `app_nav.dart`'s dispatch
/// must agree on — kept in sync by hand (a path added to `getPages`
/// without a matching entry here throws inside GetX's route resolver
/// the first time something pushes it) and checked by
/// `test/url_routing_stage3_sync_test.dart`.
const Set<String> kRegisteredRoutePaths = {
  '/about',
  '/highlights',
  '/feedback',
  '/videos',
  '/songs',
  '/stats',
  '/songs/downloads',
  '/songs/playlists',
  '/profiles',
  '/family-tree',
  '/timeline',
  '/chronology',
  '/sermons',
  '/misconceptions',
  '/sermons/:id',
  '/strongs/:number',
  '/songs/playlists/:id',
  '/videos/:id',
  '/evidence/:id',
  '/maps/:id',
  // URL-routing Stage 5 (`docs/url-routing-plan.md` §6 batch 3): the
  // multi-param / enum pages. `/settings` and `/library` are registered
  // TWICE each — once bare, once with the optional segment the plan
  // writes in §3 as `:section?` / `:tab?`. GetX has no
  // optional-segment syntax (`ParseRouteTree` splits on `/` and matches
  // segment counts, exactly as [matchesRegisteredRoute] does), so the
  // optional form is two concrete templates, not one. Verified in a
  // widget test that a literal and a template sibling coexist and each
  // resolve to their own page.
  '/settings',
  '/settings/:section',
  '/library',
  '/library/:tab',
  // The two optional filters on `/evidence` (`filterBook`,
  // `filterChapter`) ride in a QUERY STRING
  // (`/evidence?book=John&chapter=3`), not path segments — they are
  // optional, independent and unordered, which is what a query string
  // is for. §1 already records that the Bible parser ignores unknown
  // query keys, so the two grammars cannot collide. This is why
  // [matchesRegisteredRoute] strips a query before matching.
  '/evidence',
  // Stage 5, batch 4: the two pages that used to bypass `pushPage`
  // entirely with a raw `Navigator.push(MaterialPageRoute(...))`.
  '/songs/:songId/score',
  '/songs/:songId/video',
};

/// True if [path] (a concrete path such as `/sermons/004`, or a plain
/// literal such as `/about`) matches one of [templates]. A template
/// segment starting with `:` (e.g. `/sermons/:id`) matches any single
/// path segment; every other segment must match exactly, and the
/// segment counts must be equal — so `/sermons/004/extra` and
/// `/sermons` both correctly fail to match `/sermons/:id`.
///
/// URL-routing Stage 5: a query string on [path] is stripped before
/// matching. The filters on `/evidence` travel as `?book=…&chapter=…`,
/// and the concrete path this function is asked about is whatever GetX
/// put in `route.settings.name` — which, for a query-carrying named
/// push, is the whole `/evidence?book=John&chapter=3` string (verified
/// in a widget test, not assumed). Without the strip, the route on top
/// of the stack would fail to match its own registered template and
/// `url_sync_service_web.dart` would clobber the address bar back to
/// the Bible position — the exact bug this work item exists to fix.
bool matchesRegisteredRoute(
  String path, [
  Set<String> templates = kRegisteredRoutePaths,
]) {
  final pathSegments = path.split('?').first.split('/');
  for (final template in templates) {
    final templateSegments = template.split('/');
    if (templateSegments.length != pathSegments.length) continue;
    var matched = true;
    for (var i = 0; i < templateSegments.length; i++) {
      if (templateSegments[i].startsWith(':')) continue;
      if (templateSegments[i] != pathSegments[i]) {
        matched = false;
        break;
      }
    }
    if (matched) return true;
  }
  return false;
}

/// The concrete path for the Bible-evidence list, with its two optional
/// filters in the query string.
///
/// Returns the bare `/evidence` when neither filter is set, so the
/// common case produces the short, literal path rather than
/// `/evidence?` with an empty query. [book] is the canonical ENGLISH
/// book name (what `EvidencePage.filterBook` matches on), percent-
/// encoded here because names like `1 Samuel` and `Song of Songs`
/// contain spaces.
String evidencePath({String? book, int? chapter}) {
  final params = <String>[
    if (book != null && book.isNotEmpty)
      'book=${Uri.encodeQueryComponent(book)}',
    if (chapter != null) 'chapter=$chapter',
  ];
  return params.isEmpty ? '/evidence' : '/evidence?${params.join('&')}';
}

/// The concrete path for one of a song's sub-pages —
/// `/songs/<id>/score` or `/songs/<id>/video`.
///
/// The id is percent-encoded because song ids are `<source>:<slug>`
/// (`cdc:d0180`, `fydt:122368`) and carry a literal colon. A bare colon
/// in a path segment is legal per RFC 3986 and GetX matches it fine —
/// both forms were checked against `ParseRouteTree` in a widget test —
/// but the encoded form is the one that stays correct if an id ever
/// grows a character that is NOT legal there, and GetX decodes it back
/// (`Get.parameters['songId']` reads `cdc:d0180` either way, also
/// verified rather than assumed).
String songSubPagePath(String songId, String leaf) =>
    '/songs/${Uri.encodeComponent(songId)}/$leaf';

/// Strips a raw `window.location.hash` down to the route path it names,
/// keeping any query string, or returns null for an empty/root hash.
///
/// Moved out of `url_sync_service_web.dart` (where it was `_hashToPath`)
/// in Stage 5 so the boot-hash grammar is testable off-web — that file
/// is `dart:js_interop`-gated and unreachable from the VM harness. The
/// query string is deliberately KEPT: `/evidence?book=John&chapter=3`
/// has to survive a cold load intact, and every consumer either strips
/// it itself ([matchesRegisteredRoute]) or wants it (`Get.toNamed`,
/// which turns it into `Get.parameters`).
///
/// Deliberately separate from `_parseHash`, which is Bible-grammar-
/// specific and stays untouched per docs/url-routing-plan.md §1.
String? hashToRoutePath(String rawHash) {
  final h = rawHash.startsWith('#') ? rawHash.substring(1) : rawHash;
  final pathOnly = h.split('?').first;
  if (pathOnly.isEmpty || pathOnly == '/') return null;
  return h.startsWith('/') ? h : '/$h';
}
