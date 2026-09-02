import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Shares an already-rendered PNG straight into the Instagram Stories
    // composer via the pasteboard handoff Instagram documents, instead of
    // the generic OS share sheet. See instagram_story_service.dart.
    if let controller = window?.rootViewController as? FlutterViewController {
      let instagramChannel = FlutterMethodChannel(
        name: "com.sanai.dreamai/instagram_story",
        binaryMessenger: controller.binaryMessenger)
      instagramChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "isInstagramAvailable":
          result(AppDelegate.canOpenInstagramStories())
        case "shareToStory":
          guard let args = call.arguments as? [String: Any],
            let imagePath = args["imagePath"] as? String
          else {
            result(false)
            return
          }
          result(AppDelegate.shareToInstagramStory(imagePath: imagePath))
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private static func canOpenInstagramStories() -> Bool {
    guard let url = URL(string: "instagram-stories://share") else { return false }
    return UIApplication.shared.canOpenURL(url)
  }

  private static func shareToInstagramStory(imagePath: String) -> Bool {
    // Instagram's documented URL includes `source_application` (Meta's own
    // sample code always sets it) — every reference implementation passes
    // it, and this one previously omitted it entirely. A bundle identifier
    // is enough to identify the caller for the pasteboard hand-off itself;
    // a registered Facebook App ID is only needed for the optional "back to
    // app" attribution pill on the posted story, not for sharing to work.
    let bundleId = Bundle.main.bundleIdentifier ?? "com.sanai.dreamai"
    guard let url = URL(string: "instagram-stories://share?source_application=\(bundleId)"),
      UIApplication.shared.canOpenURL(url),
      let imageData = FileManager.default.contents(atPath: imagePath)
    else {
      return false
    }

    let pasteboardItems: [String: Any] = [
      "com.instagram.sharedSticker.backgroundImage": imageData
    ]
    let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
      .expirationDate: Date().addingTimeInterval(60 * 5),
      // Without this, iOS may route the pasteboard write through
      // Universal Clipboard/Handoff instead of making it available to
      // Instagram locally right away, which can make Instagram open its
      // generic camera composer (with the "doesn't support sharing to
      // Stories" banner) instead of picking up our background image.
      .localOnly: true,
    ]
    UIPasteboard.general.setItems([pasteboardItems], options: pasteboardOptions)

    UIApplication.shared.open(url, options: [:], completionHandler: nil)
    return true
  }
}
