import Flutter
import UIKit

// 2026-06-14 (v1.3.77): our scene delegate (subclass of FlutterSceneDelegate
// so all stock scene/window setup happens via super). Activated by
// Info.plist UISceneDelegateClassName = "SceneDelegate" — which MUST match
// the @objc runtime name below. (v1.3.75 used
// "$(PRODUCT_MODULE_NAME).SceneDelegate" while the class was @objc-named
// "SceneDelegate", so iOS couldn't resolve it → no scene → BLACK SCREEN.)
//
// Purpose: register the themed-app-icon channel on the LIVE
// FlutterViewController's binaryMessenger. On Flutter 3.41's UIScene path a
// channel registered in AppDelegate.didInitializeImplicitFlutterEngine
// throws MissingPluginException on the Dart side (flutter/flutter#185935) —
// the UI's real engine belongs to the scene's FlutterViewController.
@objc(SceneDelegate)
class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene,
                      willConnectTo session: UISceneSession,
                      options connectionOptions: UIScene.ConnectionOptions) {
    // super does ALL the standard Flutter window + FlutterViewController
    // setup — never skip it (skipping/failing this is what black-screens).
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // Defer so the FlutterViewController + engine are fully attached.
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
