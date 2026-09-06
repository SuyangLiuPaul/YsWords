import 'package:flutter/material.dart';

import 'package:yswords/constants/bible_versions.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// 2026-06-22 v3 (post-Safari-crash): language-grouped version popup.
///
/// History of the design space:
///   • v1.3.98 used `showModalBottomSheet` — user feedback was
///     "感觉这个新的version的方式真的很不和谐" (it slid up from the bottom,
///     foreign placement).
///   • v1.3.100 used a custom `PopupMenuEntry<String>` subclass hosted
///     inside a `PopupMenuButton<String>` — that crashed on iPhone
///     Safari ("Null check operator used on a null value" deep inside
///     Flutter's PopupMenuRoute layout after a few opens) and was
///     reverted in v1.3.101 back to the old flat menu.
///   • v3 (this file) uses **`showMenu` with a regular `PopupMenuItem`
///     whose `enabled: false` prevents the dismiss-on-tap that
///     PopupMenuItems do, then a `StatefulBuilder` inside it manages
///     the language tab + version list**. No PopupMenuEntry subclass,
///     no custom `represents`/`height` overrides — only the well-worn
///     "PopupMenuItem hosts a stateful child" pattern.
///   • 2026-09-06: that one `PopupMenuItem` was also ONE accessibility
///     node, because `PopupMenuItemState.build` wraps every item in
///     `MergeSemantics`. See `_UnmergedPopupMenuItem` below for the
///     measurement, the consequence, and why the fix is a `PopupMenuItem`
///     subclass rather than anything resembling v1.3.100's entry.
///
/// The pill row at the top matches the chapter picker's `_testamentButton`
/// vocabulary (TextButton, primary-when-selected, 14px rounded, outline
/// border, bold). Tapping a pill swaps the editions list. Tapping a
/// version row calls `Navigator.pop(ctx, version.value)` to close the
/// menu and return the picked value, which the host wires into the
/// existing `onVersionSelected` pipeline.
Future<String?> showLanguageGroupedVersionMenu({
  required BuildContext context,
  required RelativeRect position,
  required String currentVersion,
  required AppSettings settings,
}) {
  final scheme = Theme.of(context).colorScheme;
  final initialLang = (() {
    var l = bibleVersionLanguage(currentVersion);
    final order = bibleLanguageOrder;
    if (!order.contains(l) && order.isNotEmpty) l = order.first;
    return l;
  })();

  return showMenu<String>(
    context: context,
    position: position,
    color: scheme.surface,
    elevation: 8,
    constraints: const BoxConstraints(
      minWidth: 240,
      maxWidth: 320,
    ),
    items: [
      _UnmergedPopupMenuItem<String>(
        enabled: false,
        padding: EdgeInsets.zero,
        child: _LanguageGroupedVersionBody(
          initialLang: initialLang,
          currentVersion: currentVersion,
          settings: settings,
        ),
      ),
    ],
  );
}

/// A [PopupMenuItem] that does **not** merge its descendants into one
/// accessibility node.
///
/// ## What it fixes
///
/// `PopupMenuItemState.build` ends with
/// `MergeSemantics(child: buildSemantics(child: InkWell(...)))`, and
/// `MergeSemantics` cannot be escaped from below: `_RenderObjectSemantics`
/// propagates `mergeIntoParent` to the whole subtree unconditionally
/// (`rendering/object.dart`, `_SemanticsParentData(mergeIntoParent: ...
/// || config.isMergingSemanticsOfDescendants)`), and neither
/// `Semantics(container:)` nor `explicitChildNodes` overrides it.
///
/// This picker hangs its entire body — the three language pills and every
/// version row — inside ONE entry, so with the accessibility tree on the
/// whole picker collapsed into a single node. Measured off the framework's
/// own tree on 2026-09-06 (390x844, `cuvs-yhwh`):
///
///     #9 rect=0,0,320,143 actions=focus|tap
///        label="English | 繁體中文 | 简体中文 | 和合本雅伟版(简体) | 梁家铿译本(简体)"
///          #10..#14  isMergedIntoParent=true   (the pills and the rows)
///
/// Five targets, one node, one rect. `SemanticsOwner.performAction(#9,
/// tap)` — which is exactly what Flutter web's DOM overlay dispatches when
/// the reader clicks anywhere over that rect, and what VoiceOver, Switch
/// Control and Voice Control dispatch when they activate it — ran the
/// FIRST pill: the menu stayed open and flipped to English. Measured 5/5,
/// once per target. So with assistive technology on, no reader could
/// change the Bible version at all, whatever they aimed at. (Children are
/// absorbed in inverse paint order, so the first tap handler in paint
/// order is the one that survives.)
///
/// Driven in headless Chrome against two release bundles differing only in
/// this class (`tools/web_verify_headless.mjs picker`), at three aim points
/// inside each target's own rect, replaying ONE set of measured
/// coordinates so the two builds cannot differ in where the harness aimed:
///
///     build     tree ON            tree OFF (control)
///     unfixed    0/15 correct      18/18 correct
///     fixed     18/18 correct      18/18 correct
///
/// (The unfixed build's other three legs asked for the version already
/// loaded, where doing nothing also reads as success; they are counted
/// apart rather than folded in.) The control is the load-bearing half: at
/// the identical pixels with the accessibility tree off, the unfixed build
/// selects correctly every time, so what fails is the tree and not the aim.
///
/// ## Why this shape, and not v1.3.100's
///
/// v1.3.100's `LanguageGroupedVersionEntry` subclassed `PopupMenuEntry`
/// directly: it authored its own `height` getter (a fixed 260 for a body
/// that could grow to 380 and changed size when the tab changed) and its
/// own `represents`, and it crashed iPhone Safari inside `PopupMenuRoute`
/// layout. Those are precisely the two members this class never touches —
/// it IS a `PopupMenuItem`, so `height` and `represents` are the
/// framework's own, and `showMenu` here passes no `initialValue`, which is
/// the only thing that consults either of them (`PopupMenuEntry.height`:
/// "used at the time the showMenu method is called, if the `initialValue`
/// argument is provided ... It is otherwise ignored").
///
/// The item count stays 1, so `itemSizes` / `itemKeys` are unchanged, and
/// `RenderMergeSemantics` is a `RenderProxyBox` whose only override is
/// `describeSemanticsConfiguration` (`rendering/proxy_box.dart:4379`):
/// removing it changes no layout, no paint and no geometry. Checked rather
/// than assumed — the popup frame, the body, all three pills and both rows
/// measure the same before and after (320x159, 320x143, 96x48, 320x39; see
/// the metrics test), and a screenshot of the open picker taken from each
/// of the two release bundles is byte-identical, SHA-256
/// `1254d982da5e2ca6b9cce4f48ca68ea2677759774d5483b16acc43d9ae748c6b`.
/// Only the accessibility tree differs.
///
/// ## Why not simply split the body into one entry per row
///
/// Because it fixes less and costs more. Measured on 2026-09-06 with the
/// rows as their own `PopupMenuItem`s and the pill row in one of its own:
///
///   * the rows do become addressable, but the three pills stay merged —
///     `#9 320x64 "English | 繁體中文 | 简体中文"`, children
///     `isMergedIntoParent=true`, one tap action — so a reader could still
///     never reach the two languages they were not already in;
///   * every row grows from 39 to 48 (`PopupMenuItem.height` defaults to
///     `kMinInteractiveDimension`) and the popup from 159 to 177, against
///     metrics the owner signed off across three design passes;
///   * and `showMenu` fixes its `items` list when it is called, so the
///     language tab could no longer swap the rows under it without closing
///     and reopening the menu.
///
/// Nothing a descendant can do escapes the merge either — `container:`,
/// `explicitChildNodes:` and `BlockSemantics` all still report
/// `isMergedIntoParent=true` underneath a `MergeSemantics`. The fix has to
/// sit at the item, which is what this is.
///
/// The strip is written to fail SAFE. If a future Flutter stops wrapping
/// items in `MergeSemantics`, or wraps them in something else, this returns
/// what the framework built and the picker behaves exactly as it did before
/// this change instead of breaking. `test/version_picker_semantics_test.dart`
/// asserts the strip is currently doing something, so a silent regression
/// to the merged tree is caught here rather than by a reader.
class _UnmergedPopupMenuItem<T> extends PopupMenuItem<T> {
  const _UnmergedPopupMenuItem({
    super.key,
    super.value,
    super.enabled,
    super.padding,
    super.height,
    super.child,
  });

  @override
  PopupMenuItemState<T, _UnmergedPopupMenuItem<T>> createState() =>
      _UnmergedPopupMenuItemState<T>();
}

class _UnmergedPopupMenuItemState<T>
    extends PopupMenuItemState<T, _UnmergedPopupMenuItem<T>> {
  @override
  Widget build(BuildContext context) {
    final Widget built = super.build(context);
    if (built is MergeSemantics && built.child != null) {
      return built.child!;
    }
    return built;
  }
}

class _LanguageGroupedVersionBody extends StatefulWidget {
  const _LanguageGroupedVersionBody({
    required this.initialLang,
    required this.currentVersion,
    required this.settings,
  });

  final String initialLang;
  final String currentVersion;
  final AppSettings settings;

  @override
  State<_LanguageGroupedVersionBody> createState() =>
      _LanguageGroupedVersionBodyState();
}

class _LanguageGroupedVersionBodyState
    extends State<_LanguageGroupedVersionBody> {
  late String _lang;

  @override
  void initState() {
    super.initState();
    _lang = widget.initialLang;
  }

  String _t(String key, String fallback) =>
      uiStrings[key]?[widget.settings.locale] ?? fallback;

  String _langLabel(String lang) {
    switch (lang) {
      case 'en':
        return _t('versionLangEnglish', 'English');
      case 'zh-Hant':
        return _t('versionLangTraditional', 'Traditional');
      case 'zh-Hans':
      default:
        return _t('versionLangSimplified', 'Simplified');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = widget.settings;
    final languages = bibleLanguageOrder;
    final versions = versionsForLanguage(_lang);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (languages.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                for (var i = 0; i < languages.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _languagePill(
                      context: context,
                      selected: languages[i] == _lang,
                      label: _langLabel(languages[i]),
                      onPressed: () => setState(() => _lang = languages[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (languages.length > 1)
          Divider(
            height: 1,
            thickness: 0.5,
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        for (final v in versions)
          InkWell(
            onTap: () {
              final isCurrent = v.value == widget.currentVersion;
              if (isCurrent) {
                Navigator.pop<String>(context);
              } else {
                Navigator.pop<String>(context, v.value);
              }
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          v.menuLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: settings.fontFamily,
                            fontFamilyFallback: kCjkFontFallback,
                            fontSize: 14.5,
                            fontWeight: v.value == widget.currentVersion
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: v.value == widget.currentVersion
                                ? scheme.primary
                                : scheme.onSurface,
                          ),
                        ),
                        if (v.editionYear.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              v.editionYear,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: settings.fontFamily,
                                fontFamilyFallback: kCjkFontFallback,
                                fontSize: 11,
                                color: scheme.onSurface
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (v.value == widget.currentVersion)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(Icons.check_rounded,
                          size: 18, color: scheme.primary),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _languagePill({
    required BuildContext context,
    required bool selected,
    required String label,
    required VoidCallback onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final settings = widget.settings;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: selected
            ? scheme.primary.withValues(alpha: 0.92)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.52),
        foregroundColor: selected ? scheme.onPrimary : scheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        padding: EdgeInsets.symmetric(
            horizontal: 10 * settings.menuScale,
            vertical: 8 * settings.menuScale),
        minimumSize: const Size(0, 36),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: settings.fontSize.clamp(12.0, 15.0).toDouble(),
            fontFamily: settings.fontFamily,
            fontFamilyFallback: kCjkFontFallback,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
