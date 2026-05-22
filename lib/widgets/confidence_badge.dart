import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// Small pill showing an evidence's confidence level (Definitive /
/// Strong / Circumstantial). Uses the colors defined on the
/// `BibleEvidence` model so the same hue means the same level
/// everywhere — list cards, detail page, dashboard tile.
class ConfidenceBadge extends StatelessWidget {
  final String level;
  final Color color;
  /// When true (used in detail view) renders larger with a filled
  /// background. Default is small + outlined for list cards.
  final bool prominent;

  const ConfidenceBadge({
    super.key,
    required this.level,
    required this.color,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final label = _label(level, locale);
    final fs = (settings.fontSize - (prominent ? 1 : 3))
        .clamp(10.0, 16.0)
        .toDouble();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: prominent ? 10 : 8,
        vertical: prominent ? 4 : 2,
      ),
      decoration: BoxDecoration(
        color: prominent
            ? color.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(prominent ? 8 : 6),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
          fontSize: fs,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  String _label(String level, String locale) {
    final key = 'confidence$level';
    return uiStrings[key]?[locale] ?? level;
  }
}
