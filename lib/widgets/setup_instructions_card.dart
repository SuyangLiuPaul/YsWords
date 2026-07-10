import 'package:flutter/material.dart';
import 'package:yswords/utils/clipboard_helper.dart';

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

  /// Three-locale picker. Previously the inline strings used
  /// `isZh ? ... : ...` which collapsed Hans + Hant onto the same
  /// (Simplified) text — Traditional users saw simplified copy. This
  /// helper distinguishes the three cleanly.
  String _t(String hans, String hant, String en) {
    if (locale == 'zh-Hans') return hans;
    if (locale == 'zh-Hant') return hant;
    return en;
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
    // _t() handles per-locale strings now (Hans / Hant / English).
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
            _t('一次性云端配置说明（开发者）', '一次性雲端配置說明（開發者）',
                'One-time cloud setup walkthrough (developer)'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          subtitle: Text(
            _t(
                '点击展开。普通用户无需阅读此处。',
                '點擊展開。一般使用者無需閱讀此處。',
                'Tap to expand. Normal users never need to read this.'),
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
            _quickActions(context),
            const SizedBox(height: 12),
            _step(
                ctx: context,
                // 2026-05-06: Drive API + drive.file scope steps were
                // both removed when sync moved off Drive. Replaced
                // Step 1 with "enable Realtime Database" — the
                // backend the new RealtimeDbSyncService writes to.
                n: 1,
                title: _t('启用 Firebase Realtime Database',
                    '啟用 Firebase Realtime Database',
                    'Enable Firebase Realtime Database'),
                body: _t(
                    '同步将每位用户的高亮 / 书签 / 笔记存放在 RTDB 的 '
                        'users/{uid}/sync 路径。在 Firebase 控制台中点击 '
                        '"Create Database" 即可启用。',
                    '同步將每位使用者的標亮 / 書籤 / 筆記存放在 RTDB 的 '
                        'users/{uid}/sync 路徑。在 Firebase 控制台中點擊 '
                        '「Create Database」即可啟用。',
                    'Sync stores each user\'s highlights / bookmarks / '
                        'notes at users/{uid}/sync in Realtime Database. '
                        'One click on "Create Database" in the Firebase '
                        'Console enables it.'),
                url:
                    'https://console.firebase.google.com/project/ysword/database',
                action: _t('打开 RTDB 控制台', '打開 RTDB 控制台',
                    'Open RTDB console'),
                detailKey: 'setupStep1Detail'),
            _step(
                ctx: context,
                n: 2,
                title: _t(
                    '启用 Generative Language API（Gemini）',
                    '啟用 Generative Language API（Gemini）',
                    'Enable Generative Language API (Gemini)'),
                body: _t(
                    'Netlify 函数（aiExplainWord、aiSearch）通过 API 密钥调用 '
                        '生成式语言 API。该 API 必须在密钥所属项目中启用。',
                    'Netlify 函數（aiExplainWord、aiSearch）透過 API 金鑰呼叫 '
                        '生成式語言 API。該 API 必須在金鑰所屬專案中啟用。',
                    'Netlify functions call generativelanguage.googleapis.com '
                        'via API key. The API has to be enabled in '
                        "whichever project owns the key."),
                url:
                    'https://console.cloud.google.com/apis/library/generativelanguage.googleapis.com?project=ysword',
                action: _t('打开启用页', '打開啟用頁', 'Open enable page'),
                detailKey: 'setupStep2Detail'),
            _step(
                ctx: context,
                n: 3,
                title: _t(
                    '设置 Realtime Database 安全规则',
                    '設定 Realtime Database 安全規則',
                    'Set Realtime Database security rules'),
                body: _t(
                    '在 RTDB 规则中允许已登录用户读写自己的 users/<uid>/* 路径。'
                        '默认规则会拒绝所有访问，必须先放开。',
                    '在 RTDB 規則中允許已登入使用者讀寫自己的 users/<uid>/* 路徑。'
                        '預設規則會拒絕所有存取，必須先放開。',
                    'Allow authenticated users to read/write their '
                        'own users/<uid>/* path. Default rules deny '
                        'everything — has to be opened up first.'),
                url:
                    'https://console.firebase.google.com/project/ysword/database/ysword-default-rtdb/rules',
                action: _t('打开 RTDB 规则', '打開 RTDB 規則',
                    'Open RTDB rules'),
                detailKey: 'setupStep3Detail'),
            _step(
                ctx: context,
                n: 4,
                title: _t(
                    '把 yswords.netlify.app 加入 Firebase Authorized domains',
                    '把 yswords.netlify.app 加入 Firebase Authorized domains',
                    'Add yswords.netlify.app to Firebase Authorized domains'),
                body: _t(
                    'Firebase Auth 会拒绝来自非授权来源的登录请求。',
                    'Firebase Auth 會拒絕來自非授權來源的登入請求。',
                    'Firebase Auth rejects sign-in attempts from '
                        'non-authorized origins.'),
                url:
                    'https://console.firebase.google.com/project/ysword/authentication/settings',
                action: _t('打开 Firebase Auth 设置',
                    '打開 Firebase Auth 設定',
                    'Open Firebase Auth settings'),
                detailKey: 'setupStep4Detail'),
            _step(
                ctx: context,
                n: 5,
                title: _t(
                    '在 Netlify 环境变量中设置 GEMINI_API_KEY',
                    '在 Netlify 環境變數中設定 GEMINI_API_KEY',
                    'Set GEMINI_API_KEY in Netlify env vars'),
                body: _t(
                    '在 Netlify 仪表盘中设置 GEMINI_API_KEY 环境变量。可选：GEMINI_API_KEY_BACKUP_2..9 用于备用密钥链。',
                    '在 Netlify 儀表板中設定 GEMINI_API_KEY 環境變數。可選：GEMINI_API_KEY_BACKUP_2..9 用於備用金鑰鏈。',
                    'Set the GEMINI_API_KEY env var in the Netlify '
                        'dashboard. Optional: GEMINI_API_KEY_BACKUP_2..9 '
                        'for additional fallback keys.'),
                url:
                    'https://app.netlify.com/projects/yswords/configuration/env',
                action: _t('打开 Netlify 环境变量',
                    '打開 Netlify 環境變數', 'Open Netlify env vars'),
                detailKey: 'setupStep5Detail'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _t(
                    '完成后回到上方运行"配置自检"——所有项应显示 ✅。'
                        '\n\n说明：终端用户无需启用任何 API。所有 API 在项目级（ysword）启用，与 OAuth 客户端绑定，'
                        '不与个人 Google 账号关联。Google Cloud 不允许应用以编程方式启用自身的 API'
                        '——这是项目所有者的权限，所以以上步骤无法完全自动化。',
                    '完成後回到上方執行「配置自檢」——所有項應顯示 ✅。'
                        '\n\n說明：終端使用者無需啟用任何 API。所有 API 在專案級（ysword）啟用，與 OAuth 客戶端綁定，'
                        '不與個人 Google 帳號關聯。Google Cloud 不允許應用以程式化方式啟用自身的 API'
                        '——這是專案擁有者的權限，所以以上步驟無法完全自動化。',
                    'When done, scroll up to "Run check" — all '
                        'rows should show ✅.'
                        '\n\nNote: end users never enable any API. All '
                        'APIs are enabled at project level (ysword) and '
                        'bound to the OAuth client, NOT to individual '
                        'Google accounts. Google Cloud does not allow '
                        'apps to programmatically enable their own APIs '
                        '— that is a project-owner action by design, so '
                        'the steps above cannot be fully automated.'),
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
  Widget _quickActions(BuildContext ctx) {
    const cloudShellUrl =
        'https://shell.cloud.google.com/?cloudshell_print=https%3A%2F%2Fraw.githubusercontent.com%2FSuyangLiuPaul%2FYsWords%2Fmain%2Fscripts%2Fenable-cloud-apis.sh';
    // 2026-05-06: Drive API removed from the gcloud command when sync
    // moved off Drive onto Firebase Realtime Database. Only the Gemini
    // API needs CLI enablement now; RTDB is enabled inside the Firebase
    // Console (one click) instead. The shell script still has the
    // older command form for back-compat.
    const gcloudCmd =
        'gcloud services enable generativelanguage.googleapis.com --project=ysword';
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
                  _t(
                      '快速操作：一键启用步骤 2 的 API（Gemini）',
                      '快速操作：一鍵啟用步驟 2 的 API（Gemini）',
                      'Quick action — auto-enable Step 2 API (Gemini)'),
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
            _t(
                '在 Cloud Shell 中运行 gcloud 命令——无需在本地安装任何东西。'
                    '\n步骤 1、3、4、5（RTDB、规则、Firebase 域名、Netlify 密钥）仅可手动完成。',
                '在 Cloud Shell 中執行 gcloud 命令——無需在本地安裝任何東西。'
                    '\n步驟 1、3、4、5（RTDB、規則、Firebase 網域、Netlify 金鑰）僅可手動完成。',
                'Runs the gcloud command inside Cloud Shell — no '
                    'local install needed. Steps 1, 3, 4, 5 (RTDB, '
                    'rules, Firebase domains, Netlify key) are UI-only.'),
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
                  _t('在 Cloud Shell 打开',
                      '在 Cloud Shell 打開',
                      'Open in Cloud Shell'),
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
                  _t('复制 gcloud 命令', '複製 gcloud 命令',
                      'Copy gcloud command'),
                  style: const TextStyle(fontSize: 11.5),
                ),
                onPressed: () async {
                  final ok =
                      await ClipboardHelper.copyText(gcloudCmd);
                  if (!ok || !ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(
                      _t('已复制 gcloud 命令',
                          '已複製 gcloud 命令',
                          'gcloud command copied'),
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
