import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/app_style_preset.dart' show CardMaterial;

/// 2026-05-08 (v1.1.0 — Liquid Glass design pass): primitive widgets
/// that translate Apple's iOS 26 / macOS Tahoe "Liquid Glass" material
/// to Flutter Web. Built per the WWDC25 spec and Apple's
/// Human-Interface Guidelines update.
///
/// Apple's spec is intentionally non-quantitative — the system
/// renders dynamically off the background. We approximate the *spirit*
/// using stable Flutter primitives:
///
/// • `BackdropFilter` with `ImageFilter.blur` — frosted-glass blur
///   so the underlying content shows through softly.
/// • Layered fill + thin gradient border — the "edge of glass"
///   visual that makes the surface feel like a slab, not a wash.
/// • Specular-highlight gradient — a subtle linear gradient at
///   the top of the surface (white → transparent) imitating the
///   directional highlight Apple's renderer paints in real time.
/// • Soft adaptive shadow — two layers (tight + wide) with very
///   low alpha so the glass appears to *float* above content
///   rather than being pasted onto it.
///
/// Two variants matching Apple's `Glass.regular` / `Glass.clear`:
///
/// • [LiquidGlassVariant.regular] — versatile default. Adapts
///   to any background; works for navigation surfaces, sheets,
///   tiles, popups. Ships with vibrancy-friendly fill (~0.55
///   alpha on light, ~0.6 on dark).
/// • [LiquidGlassVariant.clear] — more transparent for media-
///   rich backgrounds. Higher blur, lower fill alpha (~0.25),
///   needs the consumer to handle dimming for legibility.
///
/// Usage rule (from Apple HIG): use Liquid Glass on the
/// **navigation layer**, not nested inside content surfaces.
/// One glass element should not contain another glass element —
/// keeps hierarchy crisp and avoids visual clutter.
enum LiquidGlassVariant {
  /// Default — adaptive, legible on any backdrop.
  regular,

  /// More transparent — for hero / media-rich backdrops.
  /// Caller should overlay a dimming layer where text legibility
  /// matters.
  clear,
}

/// Concentric corner radii — outer radius for floating containers,
/// inner radius for nested controls. Apple's HIG calls for the inner
/// shape's corner radius to be `outerRadius - padding`, so the curves
/// stay parallel ("concentric"). These constants keep that math
/// consistent across the codebase.
class LiquidGlassRadius {
  static const double outer = 24.0;
  static const double inner = 16.0;
  static const double pill = 9999.0; // for fully-rounded chips
}

/// The primitive Liquid-Glass surface. Wraps a child in a stack of:
///   1. Soft outer shadow (gives the float)
///   2. BackdropFilter blur (the actual frosted-glass effect)
///   3. Translucent gradient fill (so foreground text stays legible)
///   4. Top-edge specular highlight (gradient overlay)
///   5. Hairline gradient border (the "edge of glass")
///
/// All five layers compose into a single visual that feels like
/// real material rather than a flat coloured rectangle.
class LiquidGlass extends StatelessWidget {
  /// Child rendered inside the glass surface (already padded by
  /// [padding]).
  final Widget child;

  /// Regular vs Clear — see [LiquidGlassVariant].
  final LiquidGlassVariant variant;

  /// Corner radius applied to all four corners. Defaults to
  /// [LiquidGlassRadius.outer] (24 px) which matches Apple's
  /// preferred outer shape on the navigation layer.
  final double borderRadius;

  /// Padding around the child. Concentric-radius math assumes the
  /// child's own controls use radius = `borderRadius - padding`.
  final EdgeInsets padding;

  /// Optional tint colour overlaid at low opacity. Useful for
  /// state highlights (selected chip → primary tint).
  final Color? tint;

  /// Disables the BackdropFilter and falls back to a static
  /// gradient — for users who turned on `Reduce transparency`
  /// or for performance on busy scroll surfaces. Default `false`.
  final bool disableBlur;

  /// Width / height constraints. Optional; usually the parent
  /// already constrains.
  final double? width;
  final double? height;

  const LiquidGlass({
    super.key,
    required this.child,
    this.variant = LiquidGlassVariant.regular,
    this.borderRadius = LiquidGlassRadius.outer,
    this.padding = const EdgeInsets.all(16),
    this.tint,
    this.disableBlur = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Material parameters per variant ────────────────────────────
    // These approximate the visual properties Apple's renderer
    // produces dynamically. Numbers tuned by eye against WWDC25
    // screenshots + the public iOS 26 betas.
    final double sigma;
    final double fillAlpha;
    final double borderAlpha;
    final double specularAlpha;
    switch (variant) {
      case LiquidGlassVariant.regular:
        sigma = 28;
        fillAlpha = isDark ? 0.40 : 0.55;
        borderAlpha = isDark ? 0.18 : 0.45;
        specularAlpha = isDark ? 0.06 : 0.14;
        break;
      case LiquidGlassVariant.clear:
        sigma = 36;
        fillAlpha = isDark ? 0.18 : 0.25;
        borderAlpha = isDark ? 0.10 : 0.30;
        specularAlpha = isDark ? 0.04 : 0.10;
        break;
    }

    // Surface fill colour — onto a neutral light/dark base, with
    // optional tint blend. The tint is applied at 0.18 alpha so
    // selected/active states feel like "the glass took on a hue"
    // rather than "we drew a coloured rectangle".
    final baseFill = isDark
        ? const Color(0xFFFFFFFF).withValues(alpha: fillAlpha * 0.65)
        : const Color(0xFFFFFFFF).withValues(alpha: fillAlpha);
    final fill = tint == null
        ? baseFill
        : Color.alphaBlend(tint!.withValues(alpha: 0.18), baseFill);

    // Border: a hairline gradient that's brighter at the top
    // (catches the implicit "ambient light") and dimmer at the
    // bottom — gives the slab a sense of dimensionality.
    final borderTop = (isDark
            ? const Color(0xFFFFFFFF)
            : const Color(0xFFFFFFFF))
        .withValues(alpha: borderAlpha);
    final borderBottom = (isDark
            ? const Color(0xFF000000)
            : const Color(0xFF000000))
        .withValues(alpha: borderAlpha * 0.35);

    // Specular highlight — a thin linear gradient layered at the
    // top of the surface giving the "this is curved glass catching
    // light" cue. Apple's real-time renderer animates this with
    // device motion; we keep it static (web has no gyro).
    final specular = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.center,
      colors: [
        Colors.white.withValues(alpha: specularAlpha),
        Colors.white.withValues(alpha: 0),
      ],
    );

    // Outer shadow stack: tight + wide. Replicates Apple's
    // "adaptive shadow" — depth conveyed without a heavy drop-
    // shadow blur halo.
    final shadowColor = isDark
        ? const Color(0xFF000000).withValues(alpha: 0.55)
        : const Color(0xFF000000).withValues(alpha: 0.10);
    final shadows = <BoxShadow>[
      BoxShadow(
        color: shadowColor,
        blurRadius: 4,
        spreadRadius: 0,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: shadowColor.withValues(alpha: shadowColor.a * 0.6),
        blurRadius: 24,
        spreadRadius: -4,
        offset: const Offset(0, 8),
      ),
    ];

    final radius = BorderRadius.circular(borderRadius);

    Widget surface = ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          // Layer 1: backdrop blur (the frosted-glass effect).
          if (!disableBlur)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: const SizedBox.shrink(),
              ),
            ),
          // Layer 2: translucent fill + tint.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: radius,
              ),
            ),
          ),
          // Layer 3: specular highlight on the top half.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: specular,
                borderRadius: radius,
              ),
            ),
          ),
          // Layer 4: child content (padded).
          Padding(padding: padding, child: child),
        ],
      ),
    );

    // Layer 5: hairline gradient border + outer shadow stack.
    surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadows,
      ),
      position: DecorationPosition.background,
      child: Stack(
        children: [
          surface,
          // Border drawn as a CustomPaint so it sits on top of
          // the BackdropFilter clip and appears crisp.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _GlassBorderPainter(
                  radius: borderRadius,
                  topColor: borderTop,
                  bottomColor: borderBottom,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (width != null || height != null) {
      surface = SizedBox(width: width, height: height, child: surface);
    }
    return surface;
  }
}

/// Hairline gradient border. A 1.0 px stroke that runs around the
/// rounded rectangle, brighter at the top (where the implicit "light
/// source" catches the upper edge) and darker at the bottom. The
/// gradient mimics the Fresnel-style edge highlight Apple's renderer
/// produces dynamically.
class _GlassBorderPainter extends CustomPainter {
  final double radius;
  final Color topColor;
  final Color bottomColor;

  _GlassBorderPainter({
    required this.radius,
    required this.topColor,
    required this.bottomColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topColor, bottomColor],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GlassBorderPainter old) =>
      old.radius != radius ||
      old.topColor != topColor ||
      old.bottomColor != bottomColor;
}

/// Adaptive tappable surface. Renders **whichever material** the
/// user has selected in Settings → Style preset:
///
///   • [CardMaterial.classic]    → Material 3 InkWell (the look the
///                                 app shipped with through v1.0.x)
///   • [CardMaterial.liquidGlass]→ Apple WWDC25 Liquid Glass (this
///                                 file's [LiquidGlass] primitive)
///   • [CardMaterial.paper]      → flat warm sepia with hairline
///                                 outline; no shadow
///   • [CardMaterial.carbon]     → dark high-contrast surface with
///                                 sharp drop-shadow
///
/// 2026-05-08 (v1.1.1): the v1.1.0 hard-coded glass-only behaviour
/// is gone. v1.1.1 makes the look user-pickable; existing call
/// sites (dashboard tile, search chip, welcome card) don't need to
/// change — they automatically adapt.
class LiquidGlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final LiquidGlassVariant variant;
  final double borderRadius;
  final EdgeInsets padding;
  final Color? tint;
  final String? semanticLabel;

  /// Force a specific material regardless of `settings.cardMaterial`.
  /// Useful for the Settings preset-picker preview cards (each card
  /// shows what its associated material looks like).
  final CardMaterial? forceMaterial;

  const LiquidGlassButton({
    super.key,
    required this.child,
    this.onTap,
    this.variant = LiquidGlassVariant.regular,
    this.borderRadius = LiquidGlassRadius.outer,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.tint,
    this.semanticLabel,
    this.forceMaterial,
  });

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // 2026-05-08 (v1.1.3 robustness audit): use `context.select`
    // instead of `context.watch` so the button only rebuilds when
    // `cardMaterial` itself changes — not on every unrelated
    // AppSettings field (font size, line spacing, primary colour,
    // locale, …). With ~12 dashboard tiles + ~10 search chips +
    // welcome / feedback cards all listening, watching the full
    // AppSettings caused a cascade of rebuilds whenever the user
    // dragged the font-size slider in Settings.
    var material = widget.forceMaterial ??
        context.select<AppSettings, CardMaterial>((s) => s.cardMaterial);
    final scheme = Theme.of(context).colorScheme;
    // 2026-05-08 (v1.1.2): respect OS accessibility preferences.
    // Flutter / the browser surface them as MediaQueryData flags.
    //
    //   • disableAnimations  ← `prefers-reduced-motion: reduce`
    //   • highContrast       ← `prefers-contrast: more`
    //
    // For users with reduced-motion preference, skip the AnimatedScale
    // press feedback. For users on a system that signals reduced
    // transparency or high contrast (Flutter exposes only highContrast
    // on web; reduced-transparency isn't surfaced yet), force the
    // material down to `classic` regardless of the user's pick — the
    // glass / paper / carbon variants all rely on subtle layering
    // that fails the high-contrast test.
    final mq = MediaQuery.of(context);
    final reduceMotion = mq.disableAnimations;
    // High-contrast override only applies when we're rendering the
    // user's chosen material (not when the caller forced one for a
    // preview card — preview rows want to show the actual look).
    if (mq.highContrast && widget.forceMaterial == null) {
      material = CardMaterial.classic;
    }
    // Press state pushes a stronger primary tint to create the
    // "illuminate from within" cue. Same idea applies across all
    // materials, just rendered differently.
    Color? activeTint = widget.tint;
    if (_pressed) {
      activeTint = (widget.tint ?? scheme.primary).withValues(alpha: 1);
    } else if (_hover) {
      activeTint = (widget.tint ?? scheme.primary).withValues(alpha: 0.7);
    }

    Widget surface;
    switch (material) {
      case CardMaterial.classic:
        surface = _ClassicSurface(
          borderRadius: widget.borderRadius,
          padding: widget.padding,
          tint: activeTint,
          hover: _hover,
          pressed: _pressed,
          child: widget.child,
        );
        break;
      case CardMaterial.liquidGlass:
        surface = LiquidGlass(
          variant: widget.variant,
          borderRadius: widget.borderRadius,
          padding: widget.padding,
          tint: activeTint,
          child: widget.child,
        );
        break;
      case CardMaterial.paper:
        surface = _PaperSurface(
          borderRadius: widget.borderRadius,
          padding: widget.padding,
          tint: activeTint,
          hover: _hover,
          pressed: _pressed,
          child: widget.child,
        );
        break;
      case CardMaterial.carbon:
        surface = _CarbonSurface(
          borderRadius: widget.borderRadius,
          padding: widget.padding,
          tint: activeTint,
          hover: _hover,
          pressed: _pressed,
          child: widget.child,
        );
        break;
    }

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: widget.onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          // 2026-05-08 (v1.1.2): skip the press-scale animation when
          // the OS signals `prefers-reduced-motion: reduce`.
          child: reduceMotion
              ? surface
              : AnimatedScale(
                  scale: _pressed ? 0.985 : 1.0,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: surface,
                ),
        ),
      ),
    );
  }
}

// ── Non-glass surface variants ────────────────────────────────────
// Each renders the same conceptual surface (a tappable rounded
// rectangle with optional tint) with a different material vocabulary.
// They share the surface API so [LiquidGlassButton] can swap between
// them based on `settings.cardMaterial`.

/// Material 3 — primary-tinted card with surfaceContainer fill,
/// outlineVariant border, and a soft hover/press tint. Mirrors the
/// look the app shipped with through v1.0.x.
class _ClassicSurface extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final Color? tint;
  final bool hover;
  final bool pressed;
  const _ClassicSurface({
    required this.child,
    required this.borderRadius,
    required this.padding,
    required this.tint,
    required this.hover,
    required this.pressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(borderRadius);
    final base = scheme.surface;
    Color fill = base;
    if (tint != null) {
      // Press / hover state derives from the tint's alpha (set by
      // LiquidGlassButton). Higher alpha → more saturated fill.
      final blendAlpha = (tint!.a * 0.20).clamp(0.0, 0.35).toDouble();
      fill = Color.alphaBlend(
        tint!.withValues(alpha: blendAlpha),
        base,
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Warm sepia / cream surface with a hairline outline. No shadow,
/// no fill blur — the whole UI reads "single sheet of paper".
class _PaperSurface extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final Color? tint;
  final bool hover;
  final bool pressed;
  const _PaperSurface({
    required this.child,
    required this.borderRadius,
    required this.padding,
    required this.tint,
    required this.hover,
    required this.pressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);
    // Warm cream in light mode, near-charcoal in dark — both with
    // a faint warm tint so the whole UI feels like aged paper.
    final base = isDark
        ? const Color(0xFF1B1814)
        : const Color(0xFFFBF7F0);
    Color fill = base;
    if (tint != null) {
      final blendAlpha = (tint!.a * 0.18).clamp(0.0, 0.30).toDouble();
      fill = Color.alphaBlend(
        tint!.withValues(alpha: blendAlpha),
        base,
      );
    }
    final borderColor = isDark
        ? const Color(0xFF3A332A)
        : const Color(0xFFE6DDC9);
    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Dark high-contrast surface with a sharp drop-shadow. Carbon is
/// designed to look great in dark mode but stays viable on light
/// (the surface flips to deep slate while keeping the sharp shadow).
class _CarbonSurface extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final Color? tint;
  final bool hover;
  final bool pressed;
  const _CarbonSurface({
    required this.child,
    required this.borderRadius,
    required this.padding,
    required this.tint,
    required this.hover,
    required this.pressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(borderRadius);
    // Near-black in dark mode; deep slate in light. Carbon feels
    // identical regardless of system theme — that's the point.
    final base = isDark
        ? const Color(0xFF0F1115)
        : const Color(0xFF1F2228);
    Color fill = base;
    if (tint != null) {
      final blendAlpha = (tint!.a * 0.30).clamp(0.0, 0.45).toDouble();
      fill = Color.alphaBlend(
        tint!.withValues(alpha: blendAlpha),
        base,
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(
          color: scheme.primary.withValues(alpha: hover ? 0.7 : 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.55),
            blurRadius: 0,
            spreadRadius: 0,
            offset: Offset(0, pressed ? 1 : 3),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A pill-shaped Liquid-Glass chip. Concrete styling mirrors the iOS 26
/// segmented control / filter chip; selected state uses tint blend.
class LiquidGlassChip extends StatelessWidget {
  final Widget label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? leadingIcon;

  const LiquidGlassChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LiquidGlassButton(
      onTap: onTap,
      borderRadius: LiquidGlassRadius.pill,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      tint: selected ? scheme.primary : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 16,
                color: selected ? scheme.onPrimary : scheme.onSurface),
            const SizedBox(width: 6),
          ],
          DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? scheme.onPrimary : scheme.onSurface,
            ),
            child: label,
          ),
        ],
      ),
    );
  }
}

/// Adaptive card-shaped container — picks the user's chosen
/// [CardMaterial] from Settings. Drop-in for `Card(...)` where the
/// app's framing surfaces want to follow the active style preset.
///
/// 2026-05-08 (v1.1.1): switched from glass-only to material-aware.
/// See [LiquidGlassButton] for the full set of materials.
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final LiquidGlassVariant variant;
  final double borderRadius;
  final Color? tint;
  final EdgeInsets margin;

  /// Force a specific material regardless of `settings.cardMaterial`.
  /// Used by the Settings preset previews.
  final CardMaterial? forceMaterial;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.variant = LiquidGlassVariant.regular,
    this.borderRadius = LiquidGlassRadius.outer,
    this.tint,
    this.margin = EdgeInsets.zero,
    this.forceMaterial,
  });

  @override
  Widget build(BuildContext context) {
    // 2026-05-08 (v1.1.3): same `select`-not-`watch` scoping as
    // LiquidGlassButton; avoids rebuilds on unrelated settings.
    final material = forceMaterial ??
        context.select<AppSettings, CardMaterial>((s) => s.cardMaterial);
    Widget surface;
    switch (material) {
      case CardMaterial.classic:
        surface = _ClassicSurface(
          borderRadius: borderRadius,
          padding: padding,
          tint: tint,
          hover: false,
          pressed: false,
          child: child,
        );
        break;
      case CardMaterial.liquidGlass:
        surface = LiquidGlass(
          variant: variant,
          borderRadius: borderRadius,
          padding: padding,
          tint: tint,
          child: child,
        );
        break;
      case CardMaterial.paper:
        surface = _PaperSurface(
          borderRadius: borderRadius,
          padding: padding,
          tint: tint,
          hover: false,
          pressed: false,
          child: child,
        );
        break;
      case CardMaterial.carbon:
        surface = _CarbonSurface(
          borderRadius: borderRadius,
          padding: padding,
          tint: tint,
          hover: false,
          pressed: false,
          child: child,
        );
        break;
    }
    return Padding(padding: margin, child: surface);
  }
}
