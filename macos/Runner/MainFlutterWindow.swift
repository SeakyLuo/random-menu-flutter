import Cocoa
import FlutterMacOS
import CoreLocation

class MainFlutterWindow: NSWindow {
  private let photoGeocoder = CLGeocoder()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let photos = FlutterMethodChannel(name: "com.seakyluo.random_menu/photo_library", binaryMessenger: flutterViewController.engine.binaryMessenger)
    photos.setMethodCallHandler { call, result in
      let arguments = call.arguments as! [String: String]
      do {
        switch call.method {
        case "retainFile":
          let url = URL(fileURLWithPath: arguments["path"]!)
          let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
          result(bookmark.base64EncodedString())
        case "original":
          var stale = false
          let url = try URL(resolvingBookmarkData: Data(base64Encoded: arguments["source"]!)!, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
          guard url.startAccessingSecurityScopedResource() else {
            result(FlutterError(code: "original_unavailable", message: "原图已移除或没有文件访问权限", details: nil))
            return
          }
          defer { url.stopAccessingSecurityScopedResource() }
          let destination = FileManager.default.temporaryDirectory.appendingPathComponent("original_\(UUID().uuidString).\(url.pathExtension)")
          try FileManager.default.copyItem(at: url, to: destination)
          result(destination.path)
        default: result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "photo_library", message: error.localizedDescription, details: nil))
      }
    }
    let tags = FlutterMethodChannel(name: "com.seakyluo.random_menu/tag_patterns", binaryMessenger: flutterViewController.engine.binaryMessenger)
    tags.setMethodCallHandler { call, result in handleTagPatterns(call, result: result) }
    let channel = FlutterMethodChannel(name: "com.seakyluo.random_menu/photo_location", binaryMessenger: flutterViewController.engine.binaryMessenger)
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

    super.awakeFromNib()
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
