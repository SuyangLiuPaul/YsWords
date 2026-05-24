enum DeviceClass { miniPhone, phone, tablet, desktop, tv }

class ResponsiveBreakpoints {
  static DeviceClass classOf(double width) {
    if (width < 360) return DeviceClass.miniPhone;
    if (width < 600) return DeviceClass.phone;
    if (width < 1024) return DeviceClass.tablet;
    if (width < 1920) return DeviceClass.desktop;
    return DeviceClass.tv;
  }

  static bool isPhone(double w) => w < 600;
  static bool isTabletOrWider(double w) => w >= 600;
  static bool isDesktopOrWider(double w) => w >= 1024;

  // 2026-05-24 (v1.3.20): cap reading-column width on tablet+
  // displays. Pre-fix every breakpoint returned `infinity` so a
  // 27-inch desktop monitor showed verses spanning the full
  // viewport — line lengths well past the ~75-char readability
  // ceiling that comprehension research consistently flags
  // (Bringhurst, "The Elements of Typographic Style"). Apps like
  // YouVersion, WeDevote, and iOS Books all cap at ~700-800 px
  // on desktop for this reason. Phones keep `infinity` to use
  // the full screen.
  //
  // 2026-05-24 (v1.3.33): caps RAISED significantly for two reasons:
  //   (1) The Bible app is mostly read in Chinese (CUVS-YHWH, CNV,
  //       …). CJK characters are roughly 2x wider than Latin chars,
  //       so the ~75-char ceiling translates to a wider column —
  //       50-60 Chinese chars at 16sp ≈ 1100-1300 px. The previous
  //       760/880/1040 cap pinched Chinese text to ~30-35 chars
  //       per line, which felt cramped on tablets / desktops.
  //   (2) User report on a Xiaomi Pad 7 Ultra (~1800 px wide in
  //       landscape, falls into the desktop class): the old 880
  //       cap left ~51% of the screen empty per side. Looked
  //       broken. iPad Pro 11" in landscape (1194 px, also
  //       desktop class) had a noticeable 26% margin too but the
  //       user accepted it; the Mi Pad was the clear breaking
  //       point. New caps target 5-15% margin across all common
  //       tablet sizes.
  //
  // English readers on very wide monitors will see slightly long
  // lines but the column is still capped — Bible apps that ship
  // CJK content prioritise CJK readability over an English-centric
  // line-length rule.
  static double maxContentWidth(DeviceClass dc) => switch (dc) {
        DeviceClass.miniPhone => double.infinity,
        DeviceClass.phone => double.infinity,
        // 1100 → iPad mini portrait (768) + iPad portrait (810) +
        // iPad Pro 11" portrait (834) all stay under the cap (no
        // crop). iPad Pro 12.9" portrait (1024) also stays just
        // under.
        DeviceClass.tablet => 1100,
        // 1400 → iPad Pro 11" landscape (1194) stays under (no
        // margin); Xiaomi Pad 7 Ultra landscape (~1800) gets
        // ~200 px margin per side ≈ 11% (was 26% at 880); 1920
        // monitor gets ~260 per side ≈ 13.5%.
        DeviceClass.desktop => 1400,
        // 1800 → 27" 4K monitor gets reasonable text width while
        // still leaving substantial margin on ultrawide displays.
        DeviceClass.tv => 1800,
      };

  static double readingPadding(DeviceClass dc) => switch (dc) {
        DeviceClass.miniPhone => 6,
        DeviceClass.phone => 8,
        DeviceClass.tablet => 8,
        DeviceClass.desktop => 8,
        DeviceClass.tv => 8,
      };

  static double spacingScale(DeviceClass dc) => switch (dc) {
        DeviceClass.miniPhone => 0.85,
        DeviceClass.phone => 1.0,
        DeviceClass.tablet => 1.15,
        DeviceClass.desktop => 1.25,
        DeviceClass.tv => 1.4,
      };

  static double verseIndent(DeviceClass dc) => switch (dc) {
        DeviceClass.miniPhone => 12,
        DeviceClass.phone => 16,
        DeviceClass.tablet => 16,
        DeviceClass.desktop => 16,
        DeviceClass.tv => 16,
      };

  static double chapterTileSize(DeviceClass dc) => switch (dc) {
        DeviceClass.miniPhone => 44,
        DeviceClass.phone => 55,
        DeviceClass.tablet => 60,
        DeviceClass.desktop => 64,
        DeviceClass.tv => 72,
      };

  static double loadingLogoSize(DeviceClass dc) => switch (dc) {
        DeviceClass.miniPhone => 100,
        DeviceClass.phone => 150,
        DeviceClass.tablet => 180,
        DeviceClass.desktop => 200,
        DeviceClass.tv => 240,
      };

  static double settingsMaxWidth(DeviceClass dc) => switch (dc) {
        DeviceClass.miniPhone => double.infinity,
        DeviceClass.phone => double.infinity,
        DeviceClass.tablet => 560,
        DeviceClass.desktop => 640,
        DeviceClass.tv => 720,
      };

  static double headerInset(DeviceClass dc) => switch (dc) {
        DeviceClass.miniPhone => 6,
        DeviceClass.phone => 10,
        DeviceClass.tablet => 10,
        DeviceClass.desktop => 10,
        DeviceClass.tv => 10,
      };

  static double get sidebarWidth => 280.0;
}
