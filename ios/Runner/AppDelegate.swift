import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 2026-05-24 (v1.2.98): explicit foreground-notification handling.
    // Without setting ourselves as the UNUserNotificationCenter
    // delegate, iOS treats foreground notifications as silent — they
    // land in the tray with no banner. The user reported
    // "notification 我打开了也没有" after granting permission, which
    // matches that symptom. We set the delegate here (before any
    // plugin registers as a competing delegate) and provide a
    // willPresent handler that returns full presentation options.
    //
    // flutter_local_notifications also tries to set itself as the
    // delegate; setting ours FIRST means we forward through super to
    // its handler via the standard `UNUserNotificationCenter` chain.
    // The plugin's notification-tap handling still works because the
    // didReceive call still reaches it through FlutterAppDelegate.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 2026-05-24 (v1.2.96): MethodChannel for alternate-app-icon swap.
  // v1.2.96 set this up in application(didFinishLaunchingWithOptions:)
  // but window?.rootViewController is nil at that hook in the
  // implicit-engine + scene-delegate world (the scene creates the
  // window later). The `if let` silently failed and the channel was
  // never registered — user reported "ios app icon ios也还没有变色".
  // The correct hook is didInitializeImplicitFlutterEngine, which
  // runs once the implicit engine + its pluginRegistry are ready.
  // We register on the engine's binaryMessenger so the channel is
  // alive before any Dart code can call into it.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Resolve the plugin registrar to get a binary messenger.
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "yswords-ios-icon")
    if let registrar = registrar {
      let channel = FlutterMethodChannel(
        name: "yswords/ios_icon",
        binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { (call, result) in
        switch call.method {
        case "currentIconName":
          // nil for primary icon, or the alternate-icon name (e.g.
          // "AppIcon-Red"). Lets Dart sync cached state at startup.
          result(UIApplication.shared.alternateIconName)
        case "setIcon":
          let args = call.arguments as? [String: Any]
          let name = args?["name"] as? String // null → revert to primary
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
  }

  // 2026-05-24 (v1.2.98): foreground-notification presentation. iOS
  // calls this when a local notification fires while the app is
  // active. Returning `.banner | .list | .sound | .badge` makes the
  // notification show as a banner at the top of the screen and land
  // in Notification Centre. WITHOUT this override, iOS suppresses
  // foreground notifications silently — the user's confirmation
  // notification (fired right after they toggle "Enable
  // notifications" in Settings) would never appear.
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      // iOS 10-13 used the `.alert` option for banner+list. Banner
      // and list were split out in iOS 14.
      completionHandler([.alert, .sound, .badge])
    }
  }
}
