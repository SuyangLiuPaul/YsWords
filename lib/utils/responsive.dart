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

  static double maxContentWidth(DeviceClass dc) => double.infinity;

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
