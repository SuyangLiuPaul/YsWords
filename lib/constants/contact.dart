/// The one address the app ever shows a reader.
///
/// Introduced 2026-08-31 at the user's instruction ("所有的email contact都
/// 改成 support@yahwehword.com", "app全部的"). It replaced three different
/// personal Gmail addresses — `paulsyliu@`, `paul.sy.liu@` and
/// `lsy95112@` — that had been copied into eight places across five
/// files, so "change the contact address" meant finding all of them and
/// getting all of them right.
///
/// Two reasons this is a constant rather than eight literals:
///
///   * a missed copy is invisible. Nothing fails; one screen quietly
///     keeps pointing at an old inbox, and the only way anyone finds out
///     is a reader writing to an address that no longer reaches anybody.
///   * it is on a domain the project controls. A Gmail address in
///     shipped UI cannot be redirected without shipping a new build to
///     six platforms; `support@yahwehword.com` is a Cloudflare Email
///     Routing rule that can be pointed anywhere in a minute.
///
/// `test/support_email_test.dart` pins that no personal address comes
/// back, in `lib/` as a whole rather than in the files that happen to
/// use it today.
const String kSupportEmail = 'support@yahwehword.com';
