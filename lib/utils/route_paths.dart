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
  '/sermons',
  '/misconceptions',
  '/sermons/:id',
  '/strongs/:number',
  '/songs/playlists/:id',
};

/// True if [path] (a concrete path such as `/sermons/004`, or a plain
/// literal such as `/about`) matches one of [templates]. A template
/// segment starting with `:` (e.g. `/sermons/:id`) matches any single
/// path segment; every other segment must match exactly, and the
/// segment counts must be equal — so `/sermons/004/extra` and
/// `/sermons` both correctly fail to match `/sermons/:id`.
bool matchesRegisteredRoute(
  String path, [
  Set<String> templates = kRegisteredRoutePaths,
]) {
  final pathSegments = path.split('/');
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
