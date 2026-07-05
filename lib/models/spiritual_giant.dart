/// One figure in the 属灵伟人小传 / Spiritual Giants corpus, loaded from
/// `assets/spiritual_giants.json`.
///
/// Unlike the sermon corpus (whose bodies are large and live in
/// separate per-language text files), each biography is short
/// (~110 words per language) so all three languages ship inline in
/// the index JSON. The whole file is a few hundred KB and loads once.
///
/// Locale keys used throughout: `'en'`, `'zh-CN'`, `'zh-TW'` — the same
/// body-language codes the sermon corpus uses. The app's UI locale
/// (`'en'`, `'zh-Hans'`, `'zh-Hant'`) maps onto them via
/// [bodyLangForLocale].
class SpiritualGiant {
  /// Stable slug id, e.g. `martin-luther`. Used for deep links and as
  /// the last-read key.
  final String id;

  /// Category id grouping this figure in the list view, e.g.
  /// `reformers`. Localized for display via
  /// `spiritual_giant_categories.dart`.
  final String category;

  /// Per-language display name. Keys: `en`, `zh-CN`, `zh-TW`.
  final Map<String, String> name;

  /// Per-language one-line role / descriptor, e.g.
  /// "Reformer · Germany" — shown as the list subtitle and a meta chip.
  final Map<String, String> role;

  /// Life span for the meta chip, e.g. "1483–1546". Free-form so we can
  /// render approximate dates ("c.1328–1384") verbatim.
  final String years;

  /// Per-language biography body (~110 words). Keys: `en`, `zh-CN`,
  /// `zh-TW`.
  final Map<String, String> bio;

  const SpiritualGiant({
    required this.id,
    required this.category,
    required this.name,
    required this.role,
    required this.years,
    required this.bio,
  });

  factory SpiritualGiant.fromJson(Map<String, dynamic> j) {
    Map<String, String> strMap(dynamic v) {
      final m = v as Map<String, dynamic>? ?? const {};
      return {for (final e in m.entries) e.key: e.value.toString()};
    }

    return SpiritualGiant(
      id: j['id'] as String,
      category: j['category'] as String? ?? '',
      name: strMap(j['name']),
      role: strMap(j['role']),
      years: j['years'] as String? ?? '',
      bio: strMap(j['bio']),
    );
  }

  /// Map an app UI locale (`en` / `zh-Hans` / `zh-Hant`) to the
  /// body-language key (`en` / `zh-CN` / `zh-TW`) used in the JSON.
  static String bodyLangForLocale(String appLocale) {
    switch (appLocale) {
      case 'zh-Hant':
        return 'zh-TW';
      case 'zh-Hans':
        return 'zh-CN';
      default:
        return 'en';
    }
  }

  String _pick(Map<String, String> field, String appLocale) {
    final preferred = bodyLangForLocale(appLocale);
    final fallbacks = <String>[
      preferred,
      if (preferred != 'zh-CN') 'zh-CN',
      if (preferred != 'zh-TW') 'zh-TW',
      if (preferred != 'en') 'en',
    ];
    for (final lang in fallbacks) {
      final v = field[lang];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  /// Best display name for the given app locale, falling back across
  /// languages so we always return something non-empty.
  String localizedName(String appLocale) {
    final n = _pick(name, appLocale);
    return n.isNotEmpty ? n : '#$id';
  }

  /// Best role / descriptor line for the given app locale.
  String localizedRole(String appLocale) => _pick(role, appLocale);

  /// Best biography body for the given app locale.
  String localizedBio(String appLocale) => _pick(bio, appLocale);

  /// True when a biography body exists for the given body-language key.
  bool hasLang(String bodyLang) {
    final v = bio[bodyLang];
    return v != null && v.trim().isNotEmpty;
  }
}
