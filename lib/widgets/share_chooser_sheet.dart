import 'package:flutter/material.dart';
import 'package:yswords/constants/ui_strings.dart';

/// The share button asks which kind of share, instead of guessing.
///
/// Before 2026-09-09 the share icon on the selection bar silently
/// copied text-plus-link, and the picture lived behind a different
/// icon further along a row the reader could not tell was scrollable.
/// The owner asked for the obvious thing: press share, then choose
/// 「分享 link 还是图片」. Two tiles, each saying what will happen —
/// the link tile *copies*, it does not open a share sheet, and the
/// subtitle says so rather than letting the reader find out.
///
/// The callbacks run after the sheet has closed, so the image path can
/// open its own sheet without stacking two.
Future<void> showShareChooser(
  BuildContext context, {
  required String locale,
  required double menuScale,
  required VoidCallback onLink,
  required VoidCallback onImage,
}) async {
  final ms = menuScale;
  final choice = await showModalBottomSheet<_ShareChoice>(
    // useSafeArea: without it Flutter wraps the sheet in
    // MediaQuery.removePadding(removeTop: true), so any SafeArea
    // INSIDE the sheet sees padding.top == 0 and does nothing.
    useSafeArea: true,
    context: context,
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(8 * ms, 12 * ms, 8 * ms, 8 * ms),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 4 * ms),
              child: Text(
                uiStrings['shareLink']?[locale] ?? 'Share',
                style: TextStyle(
                  fontSize: 16 * ms,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.link_rounded, size: 24 * ms),
              title: Text(uiStrings['shareAsLink']?[locale] ?? 'Share link'),
              subtitle: Text(uiStrings['shareAsLinkHint']?[locale] ??
                  'Copies the text and a link to paste anywhere'),
              onTap: () => Navigator.of(sheetCtx).pop(_ShareChoice.link),
            ),
            ListTile(
              leading: Icon(Icons.image_outlined, size: 24 * ms),
              title:
                  Text(uiStrings['shareAsImage']?[locale] ?? 'Share image'),
              subtitle: Text(uiStrings['shareAsImageHint']?[locale] ??
                  'Makes a verse card to save or send'),
              onTap: () => Navigator.of(sheetCtx).pop(_ShareChoice.image),
            ),
          ],
        ),
      ),
    ),
  );
  switch (choice) {
    case _ShareChoice.link:
      onLink();
    case _ShareChoice.image:
      onImage();
    case null:
      break;
  }
}

enum _ShareChoice { link, image }
