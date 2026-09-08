// The preview + picker the reader actually touches, and the only place
// that knows how to turn what they picked into a delivered file.
//
// Scope was the hard part here, not mechanism. 微读 ships a card editor
// AND a gallery AND a poster export; YouVersion ships a photo library
// with four sliders. Both are answering "how do I make this mine",
// which is a real question, but every control added is another decision
// between a reader and sending a verse to a friend. What is here is
// three backgrounds by two brightnesses — six cards, all of them
// already in the app's palette, none of them a choice you can get
// wrong.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/verse_card_export.dart';
import 'package:yswords/services/verse_card_service.dart';
import 'package:yswords/utils/floating_toast.dart' show showFloatingToast;
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/widgets/verse_card.dart';

/// Bottom sheet showing a live [VerseCard] with the handful of
/// presentation choices the feature offers, plus the one button that
/// exports it.
class VerseCardSheet extends StatefulWidget {
  /// Localised citation, already formatted by the caller.
  final String reference;

  /// Verse text, already sanitised for display.
  final String body;

  /// Version code — `kjv`, `cuvs-yhwh`. Decides the credit line and
  /// whether this sheet may be opened at all.
  final String version;

  /// The version's short label, as the reading pane's own pill shows it.
  final String versionLabel;

  /// Text to send alongside the image on the share-sheet route. Reuses
  /// whatever the caller would have put on the clipboard, so a reader
  /// who shares the picture also sends something searchable.
  final String shareText;

  const VerseCardSheet({
    super.key,
    required this.reference,
    required this.body,
    required this.version,
    required this.versionLabel,
    required this.shareText,
  });

  /// Open the sheet, or explain why it cannot open.
  ///
  /// **On a restricted edition this toasts instead of opening, and the
  /// button stays visible.** That is a deliberate divergence from the
  /// version picker, which hides withheld editions outright rather
  /// than greying them out (`bible_versions.dart` argues that case at
  /// length). The situations are not the same: there, a greyed-out row
  /// told the reader about a translation they could do nothing about.
  /// Here the translation is right in front of them and there IS
  /// something to do — Copy shares the same verse as text — so the
  /// message is worth more than the silence.
  static Future<void> show(
    BuildContext context, {
    required String reference,
    required String body,
    required String version,
    required String versionLabel,
    required String shareText,
  }) async {
    final locale = context.read<AppSettings>().locale;
    if (!verseImageAllowed(version)) {
      showFloatingToast(
        context,
        message: uiStrings['verseCardVersionExcluded']?[locale] ??
            'This translation is not available as an image.',
        icon: Icons.info_outline_rounded,
        background: Theme.of(context).colorScheme.inverseSurface,
        duration: const Duration(milliseconds: 3200),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => VerseCardSheet(
        reference: reference,
        body: body,
        version: version,
        versionLabel: versionLabel,
        shareText: shareText,
      ),
    );
  }

  @override
  State<VerseCardSheet> createState() => _VerseCardSheetState();
}

class _VerseCardSheetState extends State<VerseCardSheet> {
  final GlobalKey _boundaryKey = GlobalKey();
  VerseCardStyle _style = VerseCardStyle.plain;
  Brightness? _brightness;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    // Opens matching the app the reader is already looking at; the
    // toggle is for choosing a card that suits where they are sending
    // it, not for correcting a bad default.
    final brightness = _brightness ?? Theme.of(context).brightness;
    final cardScheme = verseCardScheme(
      seed: settings.primaryColor,
      brightness: brightness,
    );

    return SafeArea(
      top: false,
      // Scrollable because the preview is sized as a fraction of the
      // screen and the controls under it are not: on a phone held
      // sideways the two together are taller than the sheet, and the
      // reader would lose the export button rather than the top of the
      // card.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              uiStrings['verseCardTitle']?[locale] ?? 'Verse image',
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            // The preview shrinks to fit; the export never does. The
            // boundary below is laid out at the card's true 360 dp
            // width because FittedBox hands its child unbounded
            // constraints and only then applies a scale — so a reader
            // on a small phone sees a small card and still gets the
            // same 1080 px file as everybody else.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.46,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: VerseCard(
                    reference: widget.reference,
                    body: widget.body,
                    versionLabel: widget.versionLabel,
                    licence: verseCardLicence(widget.version, locale),
                    appName: uiStrings['appName']?[locale] ??
                        "Yahweh's Words",
                    scheme: cardScheme,
                    style: _style,
                    fontFamily: settings.fontFamily,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _StyleChips(
              locale: locale,
              selected: _style,
              onSelected: (s) => setState(() => _style = s),
            ),
            const SizedBox(height: 10),
            _BrightnessToggle(
              locale: locale,
              brightness: brightness,
              onChanged: (b) => setState(() => _brightness = b),
            ),
            const SizedBox(height: 18),
            // iOS and Android are told before they tap, not after. The
            // card is already on screen at full size, which is what
            // makes "take a screenshot" an instruction rather than an
            // apology.
            if (!VerseCardExport.canDeliver)
              Text(
                uiStrings['verseCardScreenshotHint']?[locale] ??
                    'Saving images is not supported on this platform yet — '
                        'take a screenshot of the card above.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontFamilyFallback: kCjkFontFallback,
                  fontSize: 13,
                  height: 1.5,
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              FilledButton.icon(
                onPressed: _busy ? null : _export,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(VerseCardExport.canShare
                        ? Icons.ios_share_rounded
                        : Icons.download_rounded),
                // Labelled from what the platform can actually do, not
                // from what the feature is called. A "Share" button
                // that can only download is the lie this whole split
                // exists to avoid.
                label: Text(
                  VerseCardExport.canShare
                      ? (uiStrings['verseCardShare']?[locale] ?? 'Share image')
                      : (uiStrings['verseCardSave']?[locale] ?? 'Save image'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _export() async {
    final locale = context.read<AppSettings>().locale;
    // Capture BEFORE the busy state goes up, and this ordering is
    // load-bearing rather than tidy. `setState` rebuilds the card
    // along with the button, which can mark the boundary as needing
    // paint — and `captureVerseCardPng` refuses to rasterise a
    // boundary in that state rather than shipping a stale frame. The
    // capture is sub-frame work, so nothing is gained by showing a
    // spinner over it; the spinner belongs on the delivery below,
    // which is where a share sheet or a disk write actually waits.
    final png = await captureVerseCardPng(_boundaryKey);
    if (!mounted) return;
    if (png == null) {
      _report(locale, VerseCardDelivery.failed);
      return;
    }
    setState(() => _busy = true);
    final outcome = await VerseCardExport.deliver(
      png: png,
      fileName: verseCardFileName(widget.reference),
      shareText: widget.shareText,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _report(locale, outcome);
    // Dismissing on the outcomes where the reader is finished, and
    // staying put on the ones where they are not: a cancelled share
    // means they are still choosing, and an unsupported platform means
    // the card on screen is the only copy they are going to get, so
    // closing it out from under them would be actively unhelpful.
    if (outcome == VerseCardDelivery.shared ||
        outcome == VerseCardDelivery.downloaded ||
        outcome == VerseCardDelivery.savedToFile) {
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  void _report(String locale, VerseCardDelivery outcome) {
    final scheme = Theme.of(context).colorScheme;
    String? message;
    IconData icon = Icons.check_circle_rounded;
    Color background = scheme.primary;
    switch (outcome) {
      case VerseCardDelivery.shared:
        message = uiStrings['verseCardShared']?[locale] ?? 'Shared';
      case VerseCardDelivery.downloaded:
        message =
            uiStrings['verseCardDownloaded']?[locale] ?? 'Image downloaded';
      case VerseCardDelivery.savedToFile:
        final path = VerseCardExport.lastSavedPath ?? '';
        message = (uiStrings['verseCardSavedTo']?[locale] ?? 'Saved to {path}')
            .replaceAll('{path}', path);
      case VerseCardDelivery.unavailable:
        message = uiStrings['verseCardScreenshotHint']?[locale] ??
            'Saving images is not supported on this platform yet.';
        icon = Icons.info_outline_rounded;
        background = scheme.inverseSurface;
      case VerseCardDelivery.failed:
        message = uiStrings['verseCardFailed']?[locale] ??
            "Couldn't create the image.";
        icon = Icons.error_outline_rounded;
        background = scheme.error;
      case VerseCardDelivery.cancelled:
        // The reader dismissed the share sheet. They know.
        return;
    }
    showFloatingToast(
      context,
      message: message,
      icon: icon,
      background: background,
      duration: outcome == VerseCardDelivery.unavailable
          ? const Duration(milliseconds: 4000)
          : const Duration(milliseconds: 2200),
    );
  }
}

class _StyleChips extends StatelessWidget {
  final String locale;
  final VerseCardStyle selected;
  final ValueChanged<VerseCardStyle> onSelected;

  const _StyleChips({
    required this.locale,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const labels = <VerseCardStyle, String>{
      VerseCardStyle.plain: 'verseCardStylePlain',
      VerseCardStyle.tinted: 'verseCardStyleTinted',
      VerseCardStyle.gradient: 'verseCardStyleGradient',
    };
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in labels.entries)
          ChoiceChip(
            label: Text(uiStrings[entry.value]?[locale] ?? entry.value),
            selected: selected == entry.key,
            onSelected: (_) => onSelected(entry.key),
          ),
      ],
    );
  }
}

class _BrightnessToggle extends StatelessWidget {
  final String locale;
  final Brightness brightness;
  final ValueChanged<Brightness> onChanged;

  const _BrightnessToggle({
    required this.locale,
    required this.brightness,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SegmentedButton<Brightness>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: Brightness.light,
            icon: const Icon(Icons.light_mode_outlined, size: 18),
            label: Text(uiStrings['verseCardLight']?[locale] ?? 'Light'),
          ),
          ButtonSegment(
            value: Brightness.dark,
            icon: const Icon(Icons.dark_mode_outlined, size: 18),
            label: Text(uiStrings['verseCardDark']?[locale] ?? 'Dark'),
          ),
        ],
        selected: {brightness},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}
