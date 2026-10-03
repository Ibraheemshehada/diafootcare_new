import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// MARK: - UIScene lifecycle
//
// iOS 26 SDK (and later) requires UIKit apps to adopt the UIScene life cycle.
// An app linked against that SDK with no UIApplicationSceneManifest is killed at
// launch (EXC_BREAKPOINT in FrontBoardServices → UIKitCore during scene connect).
// Flutter 3.32.5 ships the classic window-based FlutterAppDelegate and has no
// FlutterSceneDelegate, so we adopt scenes manually here: build the window from
// the same Main.storyboard FlutterViewController the app has always used, and
// mirror the window onto the app delegate so plugins that reach for
// `UIApplication.shared.delegate.window` keep working.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }

    let window = UIWindow(windowScene: windowScene)
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    window.rootViewController = storyboard.instantiateInitialViewController()
    window.makeKeyAndVisible()
    self.window = window

    (UIApplication.shared.delegate as? FlutterAppDelegate)?.window = window
  }
}
