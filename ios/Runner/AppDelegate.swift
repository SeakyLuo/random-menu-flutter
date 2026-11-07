import Flutter
import UIKit
import CoreLocation
import Photos
import PhotosUI
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let photoGeocoder = CLGeocoder()
  private var photoLibrary: PhotoLibraryBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PhotoLocation")!
    photoLibrary = PhotoLibraryBridge(messenger: registrar.messenger())
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

private class PhotoLibraryBridge: NSObject, PHPickerViewControllerDelegate {
  private let channel: FlutterMethodChannel
  private var selection: FlutterResult?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.seakyluo.random_menu/photo_library", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [self] call, result in
      let arguments = call.arguments as! [String: Any]
      switch call.method {
      case "pick":
        authorize(result) { [self] in
          selection = result
          var configuration = PHPickerConfiguration(photoLibrary: .shared())
          configuration.filter = .images
          configuration.selectionLimit = (arguments["single"] as! Bool) ? 1 : 0
          configuration.preferredAssetRepresentationMode = .current
          let picker = PHPickerViewController(configuration: configuration)
          picker.delegate = self
          let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }!
          var controller = scene.windows.first { $0.isKeyWindow }!.rootViewController!
          while let next = controller.presentedViewController { controller = next }
          controller.present(picker, animated: true)
        }
      case "retainCapture":
        authorize(result) {
          var identifier: String!
          PHPhotoLibrary.shared().performChanges({
            let creation = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: URL(fileURLWithPath: arguments["path"] as! String))!
            identifier = creation.placeholderForCreatedAsset!.localIdentifier
          }) { success, error in
            DispatchQueue.main.async {
              if success { result(identifier) }
              else { result(FlutterError(code: "photo_library", message: error!.localizedDescription, details: nil)) }
            }
          }
        }
      case "original":
        authorize(result) {
          let asset = PHAsset.fetchAssets(withLocalIdentifiers: [arguments["source"] as! String], options: nil).firstObject
          guard let asset = asset else {
            result(FlutterError(code: "original_unavailable", message: "原图已删除或没有相册访问权限", details: nil))
            return
          }
          let options = PHImageRequestOptions()
          options.version = .original
          options.deliveryMode = .highQualityFormat
          options.isNetworkAccessAllowed = true
          PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, type, _, info in
            guard let data = data, let type = type, let ext = UTType(type)?.preferredFilenameExtension else {
              DispatchQueue.main.async { result(FlutterError(code: "original_unavailable", message: "无法读取原图，请检查相册权限或网络连接", details: nil)) }
              return
            }
            self.write(data, extension: ext, result: result)
          }
        }
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func authorize(_ result: @escaping FlutterResult, completion: @escaping () -> Void) {
    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
      DispatchQueue.main.async {
        if status == .authorized || status == .limited { completion() }
        else { result(FlutterError(code: "photo_permission", message: "请允许相册访问，以便保存与查看原图", details: nil)) }
      }
    }
  }

  private func write(_ data: Data, extension ext: String, result: @escaping FlutterResult) {
    do {
      let destination = FileManager.default.temporaryDirectory.appendingPathComponent("original_\(UUID().uuidString).\(ext)")
      try data.write(to: destination, options: .atomic)
      DispatchQueue.main.async { result(destination.path) }
    } catch {
      DispatchQueue.main.async { result(FlutterError(code: "photo_library", message: error.localizedDescription, details: nil)) }
    }
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    let reply = selection!
    selection = nil
    if results.isEmpty { reply([]); return }
    let group = DispatchGroup()
    let lock = NSLock()
    var selected = Array<[String: String]?>(repeating: nil, count: results.count)
    var failure: Error?
    for (index, photo) in results.enumerated() {
      group.enter()
      photo.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
        defer { group.leave() }
        do {
          if let error = error { throw error }
          guard let url = url, let identifier = photo.assetIdentifier else {
            throw NSError(domain: "photo_library", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法关联这张照片的相册原图"])
          }
          let destination = FileManager.default.temporaryDirectory.appendingPathComponent("picked_\(UUID().uuidString).\(url.pathExtension)")
          try FileManager.default.copyItem(at: url, to: destination)
          lock.lock()
          selected[index] = ["path": destination.path, "source": identifier]
          lock.unlock()
        } catch {
          lock.lock(); failure = error; lock.unlock()
        }
      }
    }
    group.notify(queue: .main) {
      if let failure = failure { reply(FlutterError(code: "photo_library", message: failure.localizedDescription, details: nil)) }
      else { reply(selected.map { $0! }) }
    }
  }
}
