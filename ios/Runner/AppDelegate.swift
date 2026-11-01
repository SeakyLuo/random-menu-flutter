import Flutter
import UIKit
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let photoGeocoder = CLGeocoder()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PhotoLocation")!
    let tags = FlutterMethodChannel(name: "com.seakyluo.random_menu/tag_patterns", binaryMessenger: registrar.messenger())
    tags.setMethodCallHandler { call, result in handleTagPatterns(call, result: result) }
    let channel = FlutterMethodChannel(name: "com.seakyluo.random_menu/photo_location", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [self] call, result in
      guard call.method == "reverseGeocode" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let arguments = call.arguments as! [String: Double]
      photoGeocoder.reverseGeocodeLocation(CLLocation(latitude: arguments["latitude"]!, longitude: arguments["longitude"]!), preferredLocale: Locale(identifier: "zh_CN")) { places, error in
        if let error = error {
          result(FlutterError(code: "geocode_failed", message: error.localizedDescription, details: nil))
        } else if let place = places?.first {
          result(["province": place.administrativeArea ?? "", "city": place.locality ?? "",
            "county": place.subLocality ?? "", "detail": [place.thoroughfare, place.subThoroughfare].compactMap { $0 }.joined()])
        } else {
          result(nil)
        }
      }
    }
  }
}

// The legacy Android rules use Unicode-aware ICU syntax, not Dart/JS classes.
private func handleTagPatterns(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
  guard call.method == "validate" || call.method == "match" else {
    result(FlutterMethodNotImplemented)
    return
  }
  let arguments = call.arguments as! [String: Any]
  let patterns = arguments["patterns"] as! [String]
  DispatchQueue.global(qos: .userInitiated).async {
    do {
      let expressions = try patterns.map { pattern in
        (pattern, try NSRegularExpression(pattern: "\\A(?:\(pattern))\\z"))
      }
      if call.method == "validate" {
        DispatchQueue.main.async { result(nil) }
      } else {
        let text = arguments["text"] as! String
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matched = expressions.filter { source, expression in
          (text as NSString).range(of: source, options: .literal).location != NSNotFound || expression.firstMatch(in: text, range: range) != nil
        }.map { $0.0 }
        DispatchQueue.main.async { result(matched) }
      }
    } catch {
      DispatchQueue.main.async {
        result(FlutterError(code: "invalid_pattern", message: error.localizedDescription, details: nil))
      }
    }
  }
}
