import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/avatar_picker_service.dart';
import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/language_switcher_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// Edit the active profile's display name and avatar color tile.
///
/// Independent from Google auth — even users signed in with Google
/// can rename themselves and pick a tile color (the Google photo
/// always wins as the avatar when set, but the color is the
/// fallback when image loading fails or the user signs out).
///
/// Reachable from Settings → Profiles → "Edit current profile", and
/// (2026-09-03) from tapping a profile's avatar in the Profiles list.
/// The stale claim that a long-press on the dashboard greeting opened
/// it is gone: no such handler ever existed. The dashboard avatar is
/// now tappable and opens the Profiles list, one step above this page.
class ProfileEditPage extends StatefulWidget {
  /// Test seam for the signed-in Google Account photo.
  ///
  /// `CloudAuthService.instance.currentUser` is a `firebase_auth`
  /// `User` behind a singleton with no injection point, and standing
  /// one up in a widget test means stubbing an abstract class with
  /// dozens of members to read one nullable string. This lets the
  /// provenance path — the whole point of the 2026-09-03 change — be
  /// driven by a real pump of this real page. Null in production, and
  /// the auth read below is unchanged.
  @visibleForTesting
  final String? debugGooglePhotoUrl;

  const ProfileEditPage({super.key, this.debugGooglePhotoUrl});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final TextEditingController _nameController;
  int? _selectedColorArgb;
  String? _selectedPhotoDataUrl;
  bool _saving = false;
  bool _pickingPhoto = false;

  @override
  void initState() {
    super.initState();
    final p = ProfileService.instance.current;
    _nameController = TextEditingController(text: p.name);
    _selectedColorArgb = p.avatarColorArgb;
    _selectedPhotoDataUrl = p.photoDataUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Curated palette that contrasts well with white text. Two rows
  /// on phones, one row on tablet+.
  static const _palette = <int>[
    0xFF1976D2, // blue
    0xFF388E3C, // green
    0xFF7B1FA2, // purple
    0xFFD32F2F, // red
    0xFFEF6C00, // orange
    0xFF00897B, // teal
    0xFFC2185B, // pink
    0xFF455A64, // blue-grey
    0xFF5D4037, // brown
    0xFF6D4C41, // brown-2
  ];

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final svc = ProfileService.instance;
    final id = svc.current.id;
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != svc.current.name) {
      await svc.rename(id, newName);
    }
    if (_selectedColorArgb != svc.current.avatarColorArgb) {
      await svc.setAvatarColor(id, _selectedColorArgb);
    }
    if (_selectedPhotoDataUrl != svc.current.photoDataUrl) {
      await svc.setAvatarPhoto(id, _selectedPhotoDataUrl);
    }
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _pickPhoto() async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    final dataUrl = await AvatarPickerService.pickAvatar();
    if (!mounted) return;
    setState(() {
      _pickingPhoto = false;
      if (dataUrl != null) _selectedPhotoDataUrl = dataUrl;
    });
  }

  void _removePhoto() {
    setState(() => _selectedPhotoDataUrl = null);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    final initial = _nameController.text.trim().isEmpty
        ? '?'
        : _nameController.text.trim().characters.first.toUpperCase();
    final previewColor =
        _selectedColorArgb != null ? Color(_selectedColorArgb!) : scheme.primary;

    // 2026-09-03: the photo the rest of the app actually shows for
    // this person. Everywhere else — the Dashboard greeting, the
    // Settings account row — a signed-in Google photo WINS over the
    // local one (`auth.currentUser?.photoURL ?? p.photoDataUrl`).
    // This page used to ignore that and preview the local photo only,
    // which is how you end up setting a photo, seeing it here, and
    // seeing something else on every other screen.
    //
    // So: preview what is really shown, and when it comes from Google
    // say so and link out, rather than offering a "Change photo"
    // button that cannot change the picture the user is looking at.
    // The queue item's own words — a control that looks editable and
    // is not is worse than one that explains itself.
    final googlePhotoUrl = widget.debugGooglePhotoUrl ??
        CloudAuthService.instance.currentUser?.photoURL;
    final showingGooglePhoto =
        googlePhotoUrl != null && googlePhotoUrl.isNotEmpty;
    final previewPhotoUrl =
        showingGooglePhoto ? googlePhotoUrl : _selectedPhotoDataUrl;

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(
          uiStrings['profileEditTitle']?[locale] ?? 'Edit profile',
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(uiStrings['save']?[locale] ?? 'Save'),
          ),
          const LanguageSwitcherButton(),
          const HomeIconButton(),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Big preview avatar at the top so the user sees the
              // result of their selections immediately. Shows the
              // photo the rest of the app shows — see the
              // `showingGooglePhoto` note above.
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: previewColor,
                  foregroundColor: Colors.white,
                  // v1.3.20: ResizeImage caps the preview decode at
                  // 192px (radius 48 → 96px display, 2× for Retina).
                  backgroundImage: previewPhotoUrl != null
                      ? ResizeImage(NetworkImage(previewPhotoUrl),
                          width: 192, height: 192)
                      : null,
                  // See the note in profiles_page.dart: `backgroundImage`
                  // is a DecorationImage and gets none of the `Image`
                  // widget's error suppression, so without this a photo
                  // that fails to load mails a crash report. Pinned by
                  // `test/image_network_audit_test.dart`.
                  onBackgroundImageError:
                      previewPhotoUrl != null ? (_, __) {} : null,
                  child: previewPhotoUrl != null
                      ? null
                      : Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              // Where the photo comes from, when the answer is "not
              // from here". Shown INSTEAD of the local picker, not
              // beside it: offering both would be the same lie in a
              // smaller font.
              if (showingGooglePhoto)
                _GooglePhotoProvenance(locale: locale, settings: settings),
              // Set / Remove photo actions — local photos only.
              if (!showingGooglePhoto && AvatarPickerService.isAvailable)
                Center(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            _pickingPhoto || _saving ? null : _pickPhoto,
                        icon: const Icon(Icons.photo_camera_outlined,
                            size: 18),
                        label: Text(
                          _selectedPhotoDataUrl == null
                              ? (uiStrings['setPhoto']?[locale] ??
                                  'Set photo')
                              : (uiStrings['changePhoto']?[locale] ??
                                  'Change photo'),
                        ),
                      ),
                      if (_selectedPhotoDataUrl != null)
                        TextButton.icon(
                          onPressed:
                              _pickingPhoto || _saving ? null : _removePhoto,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: Text(
                            uiStrings['removePhoto']?[locale] ??
                                'Remove photo',
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                uiStrings['displayName']?[locale] ?? 'Display name',
                style: TextStyle(
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                  fontSize:
                      (settings.fontSize - 2).clamp(12.0, 20.0).toDouble(),
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  isDense: true,
                  hintText: uiStrings['welcomeNameHint']?[locale] ??
                      'Your name',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              Text(
                uiStrings['avatarColor']?[locale] ?? 'Avatar color',
                style: TextStyle(
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                  fontSize:
                      (settings.fontSize - 2).clamp(12.0, 20.0).toDouble(),
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  // "Default" swatch — clears the override and falls
                  // back to scheme.primary.
                  _ColorSwatch(
                    color: scheme.primary,
                    selected: _selectedColorArgb == null,
                    isDefault: true,
                    onTap: () =>
                        setState(() => _selectedColorArgb = null),
                  ),
                  for (final argb in _palette)
                    _ColorSwatch(
                      color: Color(argb),
                      selected: _selectedColorArgb == argb,
                      isDefault: false,
                      onTap: () =>
                          setState(() => _selectedColorArgb = argb),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                uiStrings['profileEditNotice']?[locale] ??
                    'Profile name and color are stored on this device. If you\'re signed in with Google your photo will appear instead of the colored initial.',
                style: TextStyle(
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                  fontSize:
                      (settings.fontSize - 3).clamp(11.0, 16.0).toDouble(),
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final bool isDefault;
  final VoidCallback onTap;
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.isDefault,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.onSurface : Colors.transparent,
            width: selected ? 2 : 0,
          ),
        ),
        alignment: Alignment.center,
        child: isDefault
            ? Icon(Icons.refresh,
                size: 18, color: scheme.onPrimary)
            : (selected
                ? Icon(Icons.check,
                    size: 22, color: scheme.onPrimary)
                : null),
      ),
    );
  }
}

/// 2026-09-03: where a Google-account photo comes from, and how to
/// change it — which is not here.
///
/// The queue item asked for an opinion as much as a feature: a photo
/// the app cannot edit should say so and point at the place that can,
/// rather than render a "Change photo" button that quietly does
/// nothing to the picture on screen. Signing out of Google is the
/// other honest answer, so it is stated rather than left to be
/// discovered.
class _GooglePhotoProvenance extends StatelessWidget {
  final String locale;
  final AppSettings settings;
  const _GooglePhotoProvenance({required this.locale, required this.settings});

  /// Google's own "Personal info" page — the page that owns the
  /// account photo. Not a deep link into a photo picker: Google moves
  /// those, and a 404 would be worse than one extra click.
  static const String _kGoogleAccountPhotoUrl =
      'https://myaccount.google.com/personal-info';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.account_circle_outlined,
                  size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  uiStrings['photoFromGoogle']?[locale] ??
                      'This photo comes from your Google Account.',
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontFamilyFallback: kCjkFontFallback,
                    fontSize: (settings.fontSize - 2).clamp(12.0, 16.0),
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            uiStrings['photoFromGoogleDetail']?[locale] ??
                'It cannot be changed in this app. Sign out of Google to '
                    'use a photo stored on this device instead.',
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontFamilyFallback: kCjkFontFallback,
              fontSize: (settings.fontSize - 3).clamp(11.0, 15.0),
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => LinkOpener.openOrWarn(
                  context, _kGoogleAccountPhotoUrl,
                  locale: locale),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(
                uiStrings['photoChangeInGoogle']?[locale] ??
                    'Change it in your Google Account',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
