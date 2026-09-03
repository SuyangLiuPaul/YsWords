import 'package:flutter/material.dart';

/// Shared profile avatar — renders the user's photo when available,
/// falling back to a colored circle with their initial. Used by the
/// Dashboard greeting card AND the Settings account row so the same
/// person sees the same avatar everywhere.
///
/// Resolution priority (matches the dashboard convention):
///   1. [photoUrl] — Google profile photo when signed in
///      OR locally-uploaded `photoDataUrl` (a `data:image/...` URL).
///      Both go through `Image.network`, which handles `data:` URLs.
///   2. [avatarColor] — picked-by-user tile color, falls back to
///      `scheme.primary` if null.
///   3. [name] first character — uppercased initial.
///
/// 2026-09-03: the avatar is tappable, and it opens the profile.
/// User, 2026-08-16, asking for an opinion as much as a feature: a
/// circle showing your own face reads as a control whether or not it
/// is one, so leaving it inert everywhere but Settings taught people
/// that tapping their face does nothing. [onTap] lives here rather
/// than at each call site so the affordance — the ink ripple, the
/// button semantics, the label — is the same wherever the avatar
/// appears. Call sites that pass null still get a plain, inert circle.
class ProfileAvatar extends StatelessWidget {
  /// HTTPS URL or `data:` URL. Null/empty falls through to initial.
  final String? photoUrl;
  final String name;
  final int? avatarColor;
  final double radius;

  /// Opens the profile. Null renders the avatar inert (and, notably,
  /// without button semantics — a screen reader should not announce a
  /// control that isn't one).
  final VoidCallback? onTap;

  /// Accessible label for the tap target. Required in practice
  /// whenever [onTap] is set: the avatar has no text of its own, so
  /// without this a screen reader announces an unlabelled button.
  final String? tapLabel;

  const ProfileAvatar({
    super.key,
    required this.photoUrl,
    required this.name,
    this.avatarColor,
    this.radius = 24,
    this.onTap,
    this.tapLabel,
  });

  @override
  Widget build(BuildContext context) {
    final circle = _buildCircle(context);
    if (onTap == null) return circle;
    // `container: true` matters: without it this Semantics has no node
    // of its own, so [tapLabel] merges into whatever the CircleAvatar
    // below already produces (the initial letter, or nothing at all for
    // a photo) and a screen reader announces an unnamed button.
    return Semantics(
      container: true,
      button: true,
      label: tapLabel,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: circle,
      ),
    );
  }

  Widget _buildCircle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tileColor =
        avatarColor != null ? Color(avatarColor!) : scheme.primary;
    final initial =
        name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    final size = radius * 2;
    final fontSize = (radius * 0.75).clamp(11.0, 22.0).toDouble();

    if (hasPhoto) {
      // 2026-05-24 (v1.3.20) PERF: ResizeImage caps the avatar
      // decode at 2× display size. Google account photos arrive
      // at 1024×1024 by default; without this they'd sit in image
      // cache at full resolution for a 24-48 px circle, wasting
      // ~4 MB per avatar across multiple Dashboard / Settings /
      // Profiles renders.
      final cap = (size * 2).round();
      return CircleAvatar(
        radius: radius,
        backgroundColor: tileColor,
        foregroundColor: scheme.onPrimary,
        // backgroundImage gives the cached / no-flash render path
        // when the network image is good. The nested ClipOval +
        // Image.network is a defensive belt-and-suspenders that
        // handles error gracefully without surfacing a broken image.
        backgroundImage:
            ResizeImage(NetworkImage(photoUrl!), width: cap, height: cap),
        onBackgroundImageError: (_, __) {},
        child: ClipOval(
          child: Image.network(
            photoUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            // 2026-05-08 (v1.0.1 perf): cap decode at 2× display
            // size. Google account avatars can be 1024×1024 by
            // default; without this they'd be held at full
            // resolution for a 24-48 px circle.
            cacheWidth: (size * 2).round(),
            cacheHeight: (size * 2).round(),
            errorBuilder: (_, __, ___) => Text(
              initial,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: fontSize,
              ),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: tileColor,
      foregroundColor: scheme.onPrimary,
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
        ),
      ),
    );
  }
}
