import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var mapsConfigured = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let configuredKey = Bundle.main.object(forInfoDictionaryKey: "GoKawsayMapsAPIKey") as? String
    if let key = configuredKey?.trimmingCharacters(in: .whitespacesAndNewlines),
      !key.isEmpty, !key.hasPrefix("$(")
    {
      mapsConfigured = GMSServices.provideAPIKey(key)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "gokawsay/maps", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "isConfigured" {
        result(self?.mapsConfigured ?? false)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
