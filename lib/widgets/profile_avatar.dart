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
class ProfileAvatar extends StatelessWidget {
  /// HTTPS URL or `data:` URL. Null/empty falls through to initial.
  final String? photoUrl;
  final String name;
  final int? avatarColor;
  final double radius;

  const ProfileAvatar({
    super.key,
    required this.photoUrl,
    required this.name,
    this.avatarColor,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tileColor =
        avatarColor != null ? Color(avatarColor!) : scheme.primary;
    final initial =
        name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    final size = radius * 2;
    final fontSize = (radius * 0.75).clamp(11.0, 22.0).toDouble();

    if (hasPhoto) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: tileColor,
        foregroundColor: scheme.onPrimary,
        // backgroundImage gives the cached / no-flash render path
        // when the network image is good. The nested ClipOval +
        // Image.network is a defensive belt-and-suspenders that
        // handles error gracefully without surfacing a broken image.
        backgroundImage: NetworkImage(photoUrl!),
        onBackgroundImageError: (_, __) {},
        child: ClipOval(
          child: Image.network(
            photoUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
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
