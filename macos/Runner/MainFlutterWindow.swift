import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // 2026-05-24 (v1.2.97): themed Dock icon. Dart sends raw PNG
    // bytes (loaded from assets/themed_icons/<Variant>.png via
    // rootBundle.load) and we hand them to NSImage(data:) then
    // assign to NSApplication.shared.applicationIconImage. Passing
    // nil reverts to the build-time AppIcon.
    //
    // IMPORTANT LIMITATION: this only changes the Dock TILE while
    // the app is running. macOS does NOT expose a public API to
    // change the Finder / Launchpad icon at runtime — those read
    // AppIcon.icns from the bundle on disk and are effectively
    // immutable per install. So the user sees the themed icon in
    // the Dock + Cmd-Tab switcher, but Launchpad / Spotlight /
    // Finder Get-Info window stay the default light blue.
    let channel = FlutterMethodChannel(
      name: "yswords/macos_icon",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "setIconBytes":
        let args = call.arguments as? [String: Any]
        let bytes = args?["bytes"] as? FlutterStandardTypedData
        if let data = bytes?.data, let image = NSImage(data: data) {
          NSApplication.shared.applicationIconImage = image
          result(true)
        } else {
          // Nil / invalid bytes → revert to default Dock icon.
          NSApplication.shared.applicationIconImage = nil
          result(true)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
