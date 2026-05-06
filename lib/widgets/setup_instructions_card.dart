import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/services/link_opener.dart';

/// Collapsible card that mirrors the contents of `SETUP.md` so the
/// developer can see the cloud-setup walkthrough inside the app
/// (alongside the diagnostic) instead of having to flip to GitHub.
/// Default collapsed — users who never need this don't see the
/// content. Expand once and read the steps.
class SetupInstructionsCard extends StatelessWidget {
  final ColorScheme scheme;
  final String locale;
  const SetupInstructionsCard(
      {super.key, required this.scheme, required this.locale});

  Future<void> _open(String url) async {
    if (!LinkOpener.isAvailable) return;
    await LinkOpener.open(url);
  }

  /// Pops a "why this step?" dialog with the long-form explanation
  /// resolved from `uiStrings[detailKey][locale]`. Triggered by the
  /// info icon next to each step's title.
  void _showDetail(BuildContext ctx, String title, String detailKey) {
    final detail = uiStrings[detailKey]?[locale] ??
        uiStrings[detailKey]?['en'] ??
        '';
    showDialog<void>(
      context: ctx,
      builder: (dCtx) {
        final dScheme = Theme.of(dCtx).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 20, color: dScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              detail,
              style: TextStyle(
                fontSize: 13,
                color: dScheme.onSurface,
                height: 1.55,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(),
              child: Text(
                  uiStrings['setupDetailDialogClose']?[locale] ?? 'Got it'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isZh = locale.startsWith('zh');
    return Card(
      margin: EdgeInsets.zero,
      child: Theme(
        // Drop the default ExpansionTile divider lines so the card
        // stays clean and matches the surrounding cards.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding:
              const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Icon(Icons.menu_book_outlined,
              size: 18, color: scheme.primary),
          title: Text(
            isZh ? '一次性云端配置说明（开发者）' : 'One-time cloud setup walkthrough (developer)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          subtitle: Text(
            isZh
                ? '点击展开。普通用户无需阅读此处。'
                : 'Tap to expand. Normal users never need to read this.',
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
          children: [
            // 2026-05-06: "Auto-enable via Cloud Shell" shortcut.
            // Steps 1 + 2 (enabling the two APIs) are the only ones
            // that have a CLI equivalent — `gcloud services enable …`.
            // We surface a one-click "Open in Cloud Shell" button
            // that loads the script straight from the GitHub raw URL,
            // and a "Copy command" fallback for devs running gcloud
            // locally. This shaves ~8 clicks off the manual flow.
            _quickActions(context, isZh),
            const SizedBox(height: 12),
            _step(
                ctx: context,
                n: 1,
                title: isZh ? '启用 Drive API' : 'Enable Drive API',
                body: isZh
                    ? '应用使用 Drive REST 在用户的 My Drive 中读写 YsWords.json '
                        '同步文件。Drive API 必须在 OAuth 客户端所属的项目中启用。'
                    : 'The app reads & writes YsWords.json in each '
                        "user's My Drive via Drive REST. The API must be "
                        'enabled in the project that owns the OAuth client.',
                url:
                    'https://console.cloud.google.com/apis/library/drive.googleapis.com?project=ysword',
                action: isZh ? '打开启用页' : 'Open enable page',
                detailKey: 'setupStep1Detail'),
            _step(
                ctx: context,
                n: 2,
                title: isZh
                    ? '启用 Generative Language API（Gemini）'
                    : 'Enable Generative Language API (Gemini)',
                body: isZh
                    ? 'Netlify 函数（aiExplainWord、aiSearch）通过 API 密钥调用 '
                        '生成式语言 API。该 API 必须在密钥所属项目中启用。'
                    : 'Netlify functions call generativelanguage.googleapis.com '
                        'via API key. The API has to be enabled in '
                        "whichever project owns the key.",
                url:
                    'https://console.cloud.google.com/apis/library/generativelanguage.googleapis.com?project=ysword',
                action: isZh ? '打开启用页' : 'Open enable page',
                detailKey: 'setupStep2Detail'),
            _step(
                ctx: context,
                n: 3,
                title: isZh
                    ? '在 OAuth 同意屏幕添加 drive.file 范围'
                    : 'Add the drive.file scope to OAuth consent screen',
                body: isZh
                    ? '应用在登录时请求 drive.file 范围。Google 拒绝未在同意屏幕中预先列出的范围授权。'
                    : 'The app requests drive.file at sign-in time. '
                        "Google rejects scope grants that aren't "
                        'pre-listed on the consent screen.',
                url:
                    'https://console.cloud.google.com/apis/credentials/consent?project=ysword',
                action: isZh ? '打开同意屏幕' : 'Open consent screen',
                detailKey: 'setupStep3Detail'),
            _step(
                ctx: context,
                n: 4,
                title: isZh
                    ? '把 yswords.netlify.app 加入 Firebase Authorized domains'
                    : 'Add yswords.netlify.app to Firebase Authorized domains',
                body: isZh
                    ? 'Firebase Auth 会拒绝来自非授权来源的登录请求。'
                    : 'Firebase Auth rejects sign-in attempts from '
                        'non-authorized origins.',
                url:
                    'https://console.firebase.google.com/project/ysword/authentication/settings',
                action: isZh ? '打开 Firebase Auth 设置' : 'Open Firebase Auth settings',
                detailKey: 'setupStep4Detail'),
            _step(
                ctx: context,
                n: 5,
                title: isZh
                    ? '在 Netlify 环境变量中设置 GEMINI_API_KEY'
                    : 'Set GEMINI_API_KEY in Netlify env vars',
                body: isZh
                    ? '在 Netlify 仪表盘中设置 GEMINI_API_KEY 环境变量。可选：GEMINI_API_KEY_BACKUP_2..9 用于备用密钥链。'
                    : 'Set the GEMINI_API_KEY env var in the Netlify '
                        'dashboard. Optional: GEMINI_API_KEY_BACKUP_2..9 '
                        'for additional fallback keys.',
                url:
                    'https://app.netlify.com/projects/yswords/configuration/env',
                action: isZh ? '打开 Netlify 环境变量' : 'Open Netlify env vars',
                detailKey: 'setupStep5Detail'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isZh
                    ? '完成后回到上方运行"配置自检"——所有项应显示 ✅。'
                        '\n\n说明：终端用户无需启用任何 API。所有 API 在项目级（ysword）启用，与 OAuth 客户端绑定，'
                        '不与个人 Google 账号关联。Google Cloud 不允许应用以编程方式启用自身的 API'
                        '——这是项目所有者的权限，所以以上步骤无法完全自动化。'
                    : 'When done, scroll up to "Run check" — all '
                        'rows should show ✅.'
                        '\n\nNote: end users never enable any API. All '
                        'APIs are enabled at project level (ysword) and '
                        'bound to the OAuth client, NOT to individual '
                        'Google accounts. Google Cloud does not allow '
                        'apps to programmatically enable their own APIs '
                        '— that is a project-owner action by design, so '
                        'the steps above cannot be fully automated.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurface.withValues(alpha: 0.85),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One-click shortcut that opens Google Cloud Shell with the
  /// `enable-cloud-apis.sh` script preloaded — the developer hits
  /// Enter and both Drive + Gemini APIs are enabled in ~30 seconds
  /// without leaving the browser. Falls back to a "copy gcloud
  /// command" button for developers who already have gcloud
  /// installed locally.
  ///
  /// Why this exists: research showed that of the 5 setup steps,
  /// only steps 1 + 2 (API enablement) have a CLI equivalent. The
  /// other 3 (OAuth scope, Firebase domains, Netlify env vars) are
  /// UI-only by Google design. So this button automates the only
  /// thing that *can* be automated for the developer.
  Widget _quickActions(BuildContext ctx, bool isZh) {
    const cloudShellUrl =
        'https://shell.cloud.google.com/?cloudshell_print=https%3A%2F%2Fraw.githubusercontent.com%2FSuyangLiuPaul%2FYsWords%2Fmain%2Fscripts%2Fenable-cloud-apis.sh';
    const gcloudCmd =
        'gcloud services enable drive.googleapis.com generativelanguage.googleapis.com --project=ysword';
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.35),
          width: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_outlined,
                  size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isZh
                      ? '快速操作：一键启用步骤 1+2 的 API'
                      : 'Quick action — auto-enable APIs for steps 1 + 2',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isZh
                ? '在 Cloud Shell 中运行 gcloud 命令——无需在本地安装任何东西。'
                    '\n步骤 3、4、5（OAuth 范围、Firebase 域名、Netlify 密钥）'
                    '仅可手动完成，请按下方步骤操作。'
                : 'Runs the gcloud command inside Cloud Shell — no '
                    'local install needed. Steps 3, 4, 5 (OAuth scope, '
                    'Firebase domains, Netlify key) are UI-only — see '
                    'the steps below.',
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurface.withValues(alpha: 0.78),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilledButton.tonalIcon(
                icon: const Icon(Icons.terminal_rounded, size: 16),
                label: Text(
                  isZh
                      ? '在 Cloud Shell 打开'
                      : 'Open in Cloud Shell',
                  style: const TextStyle(fontSize: 11.5),
                ),
                onPressed: () => _open(cloudShellUrl),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.content_copy_rounded, size: 14),
                label: Text(
                  isZh ? '复制 gcloud 命令' : 'Copy gcloud command',
                  style: const TextStyle(fontSize: 11.5),
                ),
                onPressed: () async {
                  await Clipboard.setData(
                      const ClipboardData(text: gcloudCmd));
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(
                      isZh ? '已复制 gcloud 命令' : 'gcloud command copied',
                    ),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ));
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _step({
    required BuildContext ctx,
    required int n,
    required String title,
    required String body,
    required String url,
    required String action,
    /// Locale key for the longer "what does this step actually do
    /// and why?" explanation that appears in a popup when the user
    /// taps the info icon. Resolved against [uiStrings].
    required String detailKey,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$n',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              // Info icon — taps to a dialog with the long-form
              // explanation of WHAT this step does + WHY it's
              // needed + WHAT BREAKS without it. Adds context for
              // anyone unfamiliar with Cloud Console / OAuth.
              IconButton(
                icon: const Icon(Icons.info_outline_rounded, size: 16),
                visualDensity: VisualDensity.compact,
                tooltip: uiStrings['setupDetailTooltip']?[locale] ??
                    'Why this step?',
                onPressed: () => _showDetail(ctx, title, detailKey),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: Text(action,
                      style: const TextStyle(fontSize: 11.5)),
                  onPressed: () => _open(url),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
