import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:get/get.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/profile_edit_page.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;

/// Manage local profiles — switch active profile, add a new one,
/// rename, or delete. Reachable from Settings → Account.
class ProfilesPage extends StatefulWidget {
  const ProfilesPage({super.key});

  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  @override
  void initState() {
    super.initState();
    ProfileService.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    ProfileService.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _createProfile() async {
    final settings = context.read<AppSettings>();
    final locale = settings.locale;
    // 2026-05-07 (v18 audit): controller is created here for the
    // dialog's TextField and MUST be disposed once the dialog
    // closes — otherwise every "Create profile" tap leaks a
    // controller (and every leaked controller leaks its internal
    // change listeners).
    final controller = TextEditingController();
    String? name;
    try {
      name = await showDialog<String?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(uiStrings['profileCreateTitle']?[locale] ??
              'Create profile'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText:
                  uiStrings['welcomeNameHint']?[locale] ?? 'Your name',
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(uiStrings['cancel']?[locale] ?? 'Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(controller.text.trim()),
              child: Text(uiStrings['ok']?[locale] ?? 'OK'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
    if (name == null || name.isEmpty) return;
    final p = await ProfileService.instance.create(name);
    await ProfileService.instance.setCurrent(p.id);
  }

  Future<void> _rename(Profile p) async {
    final settings = context.read<AppSettings>();
    final locale = settings.locale;
    // 2026-05-07 (v18 audit): same controller-leak fix as
    // `_createProfile`. Wrapped in try/finally so the controller
    // is disposed even if the dialog is dismissed by an exception.
    final controller = TextEditingController(text: p.name);
    String? name;
    try {
      name = await showDialog<String?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(uiStrings['profileRename']?[locale] ?? 'Rename'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(uiStrings['cancel']?[locale] ?? 'Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(controller.text.trim()),
              child: Text(uiStrings['ok']?[locale] ?? 'OK'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
    if (name == null || name.isEmpty) return;
    await ProfileService.instance.rename(p.id, name);
  }

  Future<void> _delete(Profile p) async {
    final settings = context.read<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(uiStrings['profileDelete']?[locale] ?? 'Delete profile'),
        content: Text(
          (uiStrings['profileDeleteConfirm']?[locale] ??
                  'Permanently delete "{name}" and all its notes, bookmarks, highlights and reading-plan progress on this device?')
              .replaceAll('{name}', p.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(uiStrings['cancel']?[locale] ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              uiStrings['profileDelete']?[locale] ?? 'Delete',
              style: TextStyle(color: scheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await ProfileService.instance.delete(p.id);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    final svc = ProfileService.instance;
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(uiStrings['profileTitle']?[locale] ?? 'Profiles'),
        actions: [
          IconButton(
            tooltip:
                uiStrings['profileCreateTitle']?[locale] ?? 'Create profile',
            onPressed: _createProfile,
            icon: const Icon(Icons.person_add_alt_outlined),
          ),
          const HomeIconButton(),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: svc.profiles.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final p = svc.profiles[i];
          final isActive = p.id == svc.currentId;
          final photo = p.photoDataUrl;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: p.avatarColorArgb != null
                  ? Color(p.avatarColorArgb!)
                  : (isActive
                      ? scheme.primary
                      : scheme.surfaceContainerHighest),
              foregroundColor: isActive
                  ? scheme.onPrimary
                  : scheme.onSurfaceVariant,
              // v1.3.20: ResizeImage caps decode at 80px (CircleAvatar
              // default radius 20 → 40px display, 2× for Retina).
              backgroundImage: photo != null
                  ? ResizeImage(NetworkImage(photo), width: 80, height: 80)
                  : null,
              child: photo != null
                  ? null
                  : Text(
                      p.name.isEmpty
                          ? '?'
                          : p.name.characters.first.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
            title: Text(
              p.name,
              style: TextStyle(
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? scheme.primary : scheme.onSurface,
              ),
            ),
            subtitle: p.isGuest
                ? Text(uiStrings['profileGuestSub']?[locale] ??
                    'Default — anyone using this browser')
                : Text(
                    '${(uiStrings['profileLocalOnly']?[locale] ?? 'Local profile')} • id: ${p.id}',
                    style: TextStyle(
                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                      fontSize: (settings.fontSize - 4)
                          .clamp(11.0, 15.0)
                          .toDouble(),
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (action) {
                switch (action) {
                  case 'switch':
                    svc.setCurrent(p.id);
                    break;
                  case 'edit':
                    // Editing only makes sense on the active profile
                    // (the edit page reads/writes ProfileService.current).
                    if (!isActive) svc.setCurrent(p.id);
                    Get.to(
                      () => const ProfileEditPage(),
                      transition: Transition.rightToLeft,
                    );
                    break;
                  case 'rename':
                    _rename(p);
                    break;
                  case 'delete':
                    _delete(p);
                    break;
                }
              },
              itemBuilder: (_) => [
                if (!isActive)
                  PopupMenuItem(
                    value: 'switch',
                    child: Text(uiStrings['profileSwitch']?[locale] ??
                        'Switch to this profile'),
                  ),
                PopupMenuItem(
                  value: 'edit',
                  child: Text(
                      uiStrings['editProfile']?[locale] ?? 'Edit profile'),
                ),
                PopupMenuItem(
                  value: 'rename',
                  child:
                      Text(uiStrings['profileRename']?[locale] ?? 'Rename'),
                ),
                if (!p.isGuest)
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      uiStrings['profileDelete']?[locale] ?? 'Delete',
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
              ],
            ),
            onTap: isActive ? null : () => svc.setCurrent(p.id),
          );
        },
      ),
    );
  }
}
