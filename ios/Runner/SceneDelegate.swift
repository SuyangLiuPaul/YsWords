import Flutter
import UIKit

// Stock Flutter scene delegate. (A v1.3.75 attempt to register the
// themed-icon channel here via Info.plist UISceneDelegateClassName ->
// $(PRODUCT_MODULE_NAME).SceneDelegate caused a BLACK SCREEN: the class
// was exposed to the ObjC runtime as "SceneDelegate" (via @objc) but
// Info.plist asked for "Runner.SceneDelegate", so iOS couldn't find the
// scene delegate, no window was created. Reverted — Info.plist points back
// at the stock `FlutterSceneDelegate`. See HANDOFF for the iOS-icon status.)
class SceneDelegate: FlutterSceneDelegate {

}
