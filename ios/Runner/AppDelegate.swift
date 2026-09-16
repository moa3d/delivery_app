import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // المفتاح يصل من MAPS_API_KEY في ios/Flutter/Maps.xcconfig عبر Info.plist،
    // فلا يُكتب داخل الكود المرفوع. عند غيابه تظهر الخريطة فارغة فقط بدل
    // أن ينهار التطبيق عند الإقلاع.
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "MapsApiKey") as? String,
       !apiKey.isEmpty, !apiKey.hasPrefix("$(") {
      GMSServices.provideAPIKey(apiKey)
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
