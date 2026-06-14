import Flutter
import UIKit

// 2026-06-14 (v1.3.75): our own scene delegate (a FlutterSceneDelegate
// subclass, so all of Flutter's scene behaviour is inherited via super).
// Activated by pointing Info.plist's UISceneDelegateClassName at
// `$(PRODUCT_MODULE_NAME).SceneDelegate` instead of the stock
// `FlutterSceneDelegate`.
//
// Why this exists: on Flutter 3.41's UIScene path, a MethodChannel
// registered in AppDelegate.didInitializeImplicitFlutterEngine throws
// MissingPluginException on the Dart side (flutter/flutter#185935) — the
// engine the UI actually runs on belongs to the scene's
// FlutterViewController. So the themed-app-icon channel (`yswords/ios_icon`)
// never received calls and the icon never changed. We register it here, on
// the LIVE FlutterViewController's binaryMessenger, which is the messenger
// the Dart default channel talks to.
@objc(SceneDelegate)
class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene,
                      willConnectTo session: UISceneSession,
                      options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // Defer to the next runloop so the FlutterViewController + its engine
    // are fully attached before we grab the messenger.
    DispatchQueue.main.async { [weak scene] in
      guard let windowScene = scene as? UIWindowScene else { return }
      let fvc = windowScene.windows
        .compactMap { $0.rootViewController as? FlutterViewController }
        .first
      if let fvc = fvc {
        registerYsWordsIconChannel(fvc.binaryMessenger)
      }
    }
  }
}
