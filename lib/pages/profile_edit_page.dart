import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/avatar_picker_service.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// Edit the active profile's display name and avatar color tile.
///
/// Independent from Google auth — even users signed in with Google
/// can rename themselves and pick a tile color (the Google photo
/// always wins as the avatar when set, but the color is the
/// fallback when image loading fails or the user signs out).
///
/// Reachable from Settings → Profiles → "Edit current profile" or
/// directly from the dashboard greeting card via long-press.
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

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
              // result of their selections immediately.
              // Priority: locally-uploaded photo > color tile + initial.
              // (Google profile photo overrides this elsewhere when
              // signed in — but the editor is for the LOCAL profile
              // settings, so we show what the user controls.)
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: previewColor,
                  foregroundColor: Colors.white,
                  // v1.3.20: ResizeImage caps the preview decode at
                  // 192px (radius 48 → 96px display, 2× for Retina).
                  backgroundImage: _selectedPhotoDataUrl != null
                      ? ResizeImage(NetworkImage(_selectedPhotoDataUrl!),
                          width: 192, height: 192)
                      : null,
                  child: _selectedPhotoDataUrl != null
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
              // Set / Remove photo actions.
              if (AvatarPickerService.isAvailable)
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
