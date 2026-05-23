import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 2026-05-24 (v1.2.96): wire up the MethodChannel that lets
    // Flutter swap the home-screen app icon when the user picks a
    // different theme color in Settings. Lives on the root view
    // controller's binary messenger so it's available before the
    // user can navigate to Settings.
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "yswords/ios_icon",
        binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { (call, result) in
        switch call.method {
        case "currentIconName":
          // Returns nil for the primary icon, or the alternate
          // icon name (e.g. "AppIcon-Red"). Lets Dart sync its
          // cached state on cold start.
          result(UIApplication.shared.alternateIconName)
        case "setIcon":
          let args = call.arguments as? [String: Any]
          // Null name → revert to primary icon.
          let name = args?["name"] as? String
          guard UIApplication.shared.supportsAlternateIcons else {
            result(FlutterError(
              code: "UNSUPPORTED",
              message: "Alternate icons not supported on this device",
              details: nil))
            return
          }
          UIApplication.shared.setAlternateIconName(name) { error in
            if let err = error {
              result(FlutterError(
                code: "FAILED",
                message: err.localizedDescription,
                details: nil))
            } else {
              result(true)
            }
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
