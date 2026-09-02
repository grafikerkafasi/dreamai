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
    guard let url = URL(string: "instagram-stories://share"),
      UIApplication.shared.canOpenURL(url),
      let imageData = FileManager.default.contents(atPath: imagePath)
    else {
      return false
    }

    let pasteboardItems: [String: Any] = [
      "com.instagram.sharedSticker.backgroundImage": imageData
    ]
    let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
      .expirationDate: Date().addingTimeInterval(60 * 5)
    ]
    UIPasteboard.general.setItems([pasteboardItems], options: pasteboardOptions)

    UIApplication.shared.open(url, options: [:], completionHandler: nil)
    return true
  }
}
