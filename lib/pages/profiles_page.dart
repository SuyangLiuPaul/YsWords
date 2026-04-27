import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/widgets/localized_back_button.dart';

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
    final controller = TextEditingController();
    final name = await showDialog<String?>(
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
    if (name == null || name.isEmpty) return;
    final p = await ProfileService.instance.create(name);
    await ProfileService.instance.setCurrent(p.id);
  }

  Future<void> _rename(Profile p) async {
    final settings = context.read<AppSettings>();
    final locale = settings.locale;
    final controller = TextEditingController(text: p.name);
    final name = await showDialog<String?>(
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
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: svc.profiles.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final p = svc.profiles[i];
          final isActive = p.id == svc.currentId;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isActive
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              foregroundColor: isActive
                  ? scheme.onPrimary
                  : scheme.onSurfaceVariant,
              child: Text(
                p.name.isEmpty ? '?' : p.name.characters.first.toUpperCase(),
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
                      fontSize: 11,
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
