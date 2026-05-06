import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/link_opener.dart';
import 'package:yswords/utils/clipboard_helper.dart';
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/widgets/cloud_setup_diagnostic.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// Settings → About → "About / 关于" — full attributions + licensing
/// + takedown contact page.
///
/// Why this page exists: YsWords bundles or references material that
/// belongs to other rights holders (Bible publishers, lexicon
/// projects, sermon authors, font foundries). This page is the
/// app's single source of truth for who owns what, the licence each
/// piece is used under, and how to reach the developer for
/// takedown / licensing requests.
///
/// The page is **read-only** and never gates behaviour — it's purely
/// informational. Lives behind a button on the existing
/// `_AboutCard` in Settings so the page itself can be deep enough
/// to list every Bible version + every credit without crowding the
/// Settings list.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    final dc = ResponsiveBreakpoints.classOf(
        MediaQuery.of(context).size.width);
    final maxW = ResponsiveBreakpoints.settingsMaxWidth(dc);

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(uiStrings['aboutPageTitle']?[locale] ?? 'About'),
        actions: const [HomeIconButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _Header(scheme: scheme, locale: locale, settings: settings),
              const SizedBox(height: 16),
              _DisclaimerCard(scheme: scheme, locale: locale),
              const SizedBox(height: 12),
              _ContactCard(scheme: scheme, locale: locale),
              // 2026-05-06: BYOK card was here briefly but the user
              // wanted AI to be fully automatic ("auth gemini for
              // them"). The developer-shared Gemini key already
              // handles AI for everyone after sign-in — no setup
              // needed. The BYOK widget (lib/widgets/gemini_key_card)
              // and Netlify function userApiKey support remain in
              // case we need to re-enable BYOK later.
              const SizedBox(height: 20),
              _SectionTitle(
                  text: uiStrings['aboutSectionScriptures']?[locale] ??
                      'Bundled scripture texts',
                  scheme: scheme),
              const SizedBox(height: 6),
              _ScripturesTable(scheme: scheme, locale: locale),
              const SizedBox(height: 20),
              _SectionTitle(
                  text: uiStrings['aboutSectionLexicons']?[locale] ??
                      "Strong's lexicons & original-language data",
                  scheme: scheme),
              const SizedBox(height: 6),
              _LexiconsTable(scheme: scheme, locale: locale),
              const SizedBox(height: 20),
              _SectionTitle(
                  text: uiStrings['aboutSectionOther']?[locale] ??
                      'Maps · Sermons · Fonts · AI · App icon',
                  scheme: scheme),
              const SizedBox(height: 6),
              _OtherAttributions(scheme: scheme, locale: locale),
              const SizedBox(height: 20),
              _SectionTitle(
                  text: uiStrings['aboutSectionAppLicense']?[locale] ??
                      'Application licence',
                  scheme: scheme),
              const SizedBox(height: 6),
              _AppLicenseCard(scheme: scheme, locale: locale),
              const SizedBox(height: 20),
              // 2026-05-06 — Cloud setup diagnostic. Probes Firebase
              // Auth, Drive REST, Gemini proxy. Lives at the bottom
              // of AboutPage so it doesn't clutter the main flow but
              // the developer (or anyone hitting "sync isn't working")
              // can run it and see exactly which API isn't enabled,
              // with one-click fix links to Cloud Console.
              _SectionTitle(
                  text: uiStrings['cloudDiagSection']?[locale] ??
                      'Cloud setup status (developer / diagnostic)',
                  scheme: scheme),
              const SizedBox(height: 6),
              CloudSetupDiagnostic(locale: locale),
              const SizedBox(height: 8),
              // SETUP.md content rendered in-app so the developer
              // doesn't have to flip to GitHub to find the
              // walkthrough. Collapsible (default closed) so it
              // doesn't crowd the page for normal users — they
              // never need to see it.
              _SetupInstructionsCard(scheme: scheme, locale: locale),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  uiStrings['aboutFooterNote']?[locale] ??
                      'Last updated 2026-05-06.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ColorScheme scheme;
  final String locale;
  final AppSettings settings;
  const _Header(
      {required this.scheme, required this.locale, required this.settings});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Row(
          children: [
            Icon(Icons.menu_book_rounded,
                color: scheme.primary, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    uiStrings['appName']?[locale] ?? 'YsWords',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    uiStrings['appTagline']?[locale] ??
                        'A bilingual Bible study app.',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  final ColorScheme scheme;
  final String locale;
  const _DisclaimerCard({required this.scheme, required this.locale});
  @override
  Widget build(BuildContext context) {
    return Card(
      color: scheme.tertiaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded,
                size: 18, color: scheme.tertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                uiStrings['aboutDisclaimer']?[locale] ?? '',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurface,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final ColorScheme scheme;
  final String locale;
  const _ContactCard({required this.scheme, required this.locale});

  static const _email = 'paul.sy.liu@gmail.com';

  Future<void> _open(BuildContext context) async {
    final uri = 'mailto:$_email?subject=YsWords%20copyright%20enquiry';
    if (LinkOpener.isAvailable) {
      final ok = await LinkOpener.open(uri);
      if (ok) return;
    }
    if (!context.mounted) return;
    await ClipboardHelper.copyWithFeedback(context, _email);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.alternate_email_rounded,
                    size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  uiStrings['aboutContactTitle']?[locale] ??
                      'Contact / Takedown',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              uiStrings['aboutContactBody']?[locale] ?? '',
              style: TextStyle(
                fontSize: 12.5,
                color: scheme.onSurface.withValues(alpha: 0.85),
                height: 1.55,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.email_outlined, size: 18),
                label: Text(
                  _email,
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                onPressed: () => _open(context),
              ),
            ),
            Text(
              uiStrings['aboutContactSla']?[locale] ?? '',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final ColorScheme scheme;
  const _SectionTitle({required this.text, required this.scheme});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: scheme.primary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// A row inside an attributions table. Renders the resource name, its
/// rights holder / licence, and an optional URL the user can tap.
class _AttribRow extends StatelessWidget {
  final String name;
  final String licence;
  final String? url;
  final bool last;
  const _AttribRow({
    required this.name,
    required this.licence,
    this.url,
    this.last = false,
  });

  Future<void> _open(BuildContext context) async {
    if (url == null) return;
    if (!LinkOpener.isAvailable) return;
    await LinkOpener.open(url!);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasUrl = url != null && url!.isNotEmpty;
    return InkWell(
      onTap: hasUrl ? () => _open(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: last
                  ? Colors.transparent
                  : scheme.outlineVariant.withValues(alpha: 0.5),
              width: 0.6,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: Text(
                licence,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
            if (hasUrl) ...[
              const SizedBox(width: 4),
              Icon(Icons.open_in_new_rounded,
                  size: 14,
                  color: scheme.primary.withValues(alpha: 0.75)),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttribTable extends StatelessWidget {
  final List<_AttribRow> rows;
  final ColorScheme scheme;
  const _AttribTable({required this.rows, required this.scheme});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(children: rows),
      ),
    );
  }
}

class _ScripturesTable extends StatelessWidget {
  final ColorScheme scheme;
  final String locale;
  const _ScripturesTable(
      {required this.scheme, required this.locale});
  @override
  Widget build(BuildContext context) {
    final r = <_AttribRow>[
      _AttribRow(
        name: uiStrings['aboutVerKjv']?[locale] ?? 'KJV (1611 / 1769)',
        licence: uiStrings['aboutLicensePublicDomain']?[locale] ??
            'Public domain.',
      ),
      _AttribRow(
        name: uiStrings['aboutVerLeb']?[locale] ?? 'LEB (Lexham English Bible)',
        licence: uiStrings['aboutLicenseLeb']?[locale] ??
            '© Logos Bible Software · non-commercial study only.',
        url: 'https://lexhampress.com/product/9461/lexham-english-bible',
      ),
      _AttribRow(
        name: uiStrings['aboutVerNasb']?[locale] ?? 'NASB 2020',
        licence: uiStrings['aboutLicenseNasb']?[locale] ??
            '© The Lockman Foundation · used under quotation provisions.',
        url: 'https://www.lockman.org/',
      ),
      _AttribRow(
        name: uiStrings['aboutVerCuv']?[locale] ?? 'CUV 1919 (和合本, 简/繁)',
        licence: uiStrings['aboutLicensePublicDomain']?[locale] ??
            'Public domain (1919 base text).',
      ),
      _AttribRow(
        name: uiStrings['aboutVerCuvsYhwh']?[locale] ??
            'CUVS-YHWH (和合本雅伟版, 简/繁)',
        licence: uiStrings['aboutLicenseCuvsYhwh']?[locale] ??
            '© Yahweh De Hua Ministry · used with permission.',
        url: 'https://yahwehdehua.net/cn',
      ),
      _AttribRow(
        name: uiStrings['aboutVerCnv']?[locale] ?? 'CNV 1992 / 2011 (新译本, 简/繁)',
        licence: uiStrings['aboutLicenseCnv']?[locale] ??
            '© Worldwide Bible Society · Yahweh-substituted community-study edition.',
      ),
      _AttribRow(
        name: uiStrings['aboutVerLjk']?[locale] ??
            'LJK1 / LJK2 (原文释经圣经, 简/繁)',
        licence: uiStrings['aboutLicenseLjk']?[locale] ??
            '© Bible Exegesis Ministry · used with permission.',
        url: 'https://www.biblexg.com/',
        last: true,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AttribTable(rows: r, scheme: scheme),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            uiStrings['aboutNivRemovedNote']?[locale] ?? '',
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _LexiconsTable extends StatelessWidget {
  final ColorScheme scheme;
  final String locale;
  const _LexiconsTable({required this.scheme, required this.locale});
  @override
  Widget build(BuildContext context) {
    final r = <_AttribRow>[
      _AttribRow(
        name: uiStrings['aboutLexStrongs']?[locale] ??
            "Strong's Greek + Hebrew Concordance",
        licence: uiStrings['aboutLicensePublicDomain']?[locale] ??
            'Public domain (1890s).',
      ),
      _AttribRow(
        name: uiStrings['aboutLexCbol']?[locale] ??
            'CBOL Chinese definitions',
        licence: uiStrings['aboutLicenseCbol']?[locale] ??
            'CC-BY-NC-SA 4.0 · non-commercial only; derivatives must keep the licence.',
        url: 'https://bible.fhl.net/',
      ),
      _AttribRow(
        name: uiStrings['aboutLexLxx']?[locale] ??
            'LXX (Septuagint) cross-references',
        licence: uiStrings['aboutLicensePublicDomain']?[locale] ??
            'Public domain.',
      ),
      _AttribRow(
        name: uiStrings['aboutLexInterlinear']?[locale] ??
            'Greek + Hebrew interlinear (Strong\'s-tagged)',
        licence: uiStrings['aboutLicenseInterlinear']?[locale] ??
            'Public-domain morphological databases.',
        last: true,
      ),
    ];
    return _AttribTable(rows: r, scheme: scheme);
  }
}

class _OtherAttributions extends StatelessWidget {
  final ColorScheme scheme;
  final String locale;
  const _OtherAttributions(
      {required this.scheme, required this.locale});
  @override
  Widget build(BuildContext context) {
    final r = <_AttribRow>[
      _AttribRow(
        name: uiStrings['aboutMaps']?[locale] ?? 'Bible-history maps',
        licence: uiStrings['aboutLicenseMaps']?[locale] ??
            'Public domain / Creative Commons archives.',
      ),
      _AttribRow(
        name: uiStrings['aboutSermons']?[locale] ??
            'Sermons (`assets/sermons/`)',
        licence: uiStrings['aboutLicenseSermons']?[locale] ??
            '© Liang Jia-keng · used with permission.',
      ),
      _AttribRow(
        name: uiStrings['aboutFontsBundled']?[locale] ??
            'Bundled font: Roboto',
        licence: uiStrings['aboutLicenseRoboto']?[locale] ??
            'Apache 2.0 · Google.',
      ),
      _AttribRow(
        name: uiStrings['aboutFontsGoogle']?[locale] ??
            'Runtime fonts: EB Garamond / Lora / Inter / Noto Serif SC / …',
        licence: uiStrings['aboutLicenseOfl']?[locale] ??
            'SIL OFL · loaded via google_fonts.',
        url: 'https://fonts.google.com/',
      ),
      _AttribRow(
        name: uiStrings['aboutAi']?[locale] ?? 'AI explanations',
        licence: uiStrings['aboutLicenseAi']?[locale] ??
            'Google Gemini API · output redistribution permitted under API terms.',
      ),
      _AttribRow(
        name: uiStrings['aboutTrivia']?[locale] ??
            'Trivia text + diagrams',
        licence: uiStrings['aboutLicenseOriginal']?[locale] ??
            'Original to this app · MIT (same as application code).',
      ),
      _AttribRow(
        name: uiStrings['aboutSongs']?[locale] ?? 'Songs directory',
        licence: uiStrings['aboutLicenseSongs']?[locale] ??
            'Link-out only · no audio / lyrics / PDFs are embedded.',
        last: true,
      ),
    ];
    return _AttribTable(rows: r, scheme: scheme);
  }
}

class _AppLicenseCard extends StatelessWidget {
  final ColorScheme scheme;
  final String locale;
  const _AppLicenseCard({required this.scheme, required this.locale});

  Future<void> _openRepo(BuildContext context) async {
    if (!LinkOpener.isAvailable) return;
    await LinkOpener.open('https://github.com/SuyangLiuPaul/YsWords');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              uiStrings['aboutAppLicenseHeading']?[locale] ??
                  'Application code: MIT licence',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              uiStrings['aboutAppLicenseBody']?[locale] ?? '',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.85),
                height: 1.55,
              ),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              icon: const Icon(Icons.code_rounded, size: 16),
              label: Text(
                uiStrings['aboutOpenRepo']?[locale] ??
                    'View source on GitHub',
              ),
              onPressed: () => _openRepo(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Collapsible card that mirrors the contents of `SETUP.md` so the
/// developer can see the cloud-setup walkthrough inside the app
/// (alongside the diagnostic) instead of having to flip to GitHub.
/// Default collapsed — users who never need this don't see the
/// content. Expand once and read the steps.
class _SetupInstructionsCard extends StatelessWidget {
  final ColorScheme scheme;
  final String locale;
  const _SetupInstructionsCard({required this.scheme, required this.locale});

  Future<void> _open(String url) async {
    if (!LinkOpener.isAvailable) return;
    await LinkOpener.open(url);
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
                action: isZh ? '打开启用页' : 'Open enable page'),
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
                action: isZh ? '打开启用页' : 'Open enable page'),
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
                action: isZh ? '打开同意屏幕' : 'Open consent screen'),
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
                action: isZh ? '打开 Firebase Auth 设置' : 'Open Firebase Auth settings'),
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
                action: isZh ? '打开 Netlify 环境变量' : 'Open Netlify env vars'),
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

  Widget _step({
    required BuildContext ctx,
    required int n,
    required String title,
    required String body,
    required String url,
    required String action,
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
