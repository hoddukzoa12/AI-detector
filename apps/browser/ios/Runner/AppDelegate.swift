import UIKit
import Flutter
import flutter_downloader

@UIApplicationMain

@objc class AppDelegate: FlutterAppDelegate {
  private let intentChannelName = "com.dalsoop.infocutter.intent_data"
  private var pendingOpenUrl: String?
  private var intentChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    FlutterDownloaderPlugin.setPluginRegistrantCallback(registerPlugins)

    if let url = launchOptions?[.url] as? URL {
      pendingOpenUrl = url.absoluteString
    }

    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      wireIntentChannel(controller.binaryMessenger)
    }
    return ok
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    deliverOpenUrl(url.absoluteString)
    return super.application(app, open: url, options: options)
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
      deliverOpenUrl(url.absoluteString)
    }
    return super.application(
      application,
      continue: userActivity,
      restorationHandler: restorationHandler
    )
  }

  private func wireIntentChannel(_ messenger: FlutterBinaryMessenger) {
    if intentChannel != nil { return }
    let channel = FlutterMethodChannel(
      name: intentChannelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      if call.method == "getIntentData" {
        let url = self.pendingOpenUrl
        self.pendingOpenUrl = nil
        result(url)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    intentChannel = channel
  }

  private func deliverOpenUrl(_ url: String) {
    if intentChannel == nil,
       let controller = window?.rootViewController as? FlutterViewController {
      wireIntentChannel(controller.binaryMessenger)
    }
    if let channel = intentChannel {
      channel.invokeMethod("openUrl", arguments: url)
    } else {
      pendingOpenUrl = url
    }
  }
}

private func registerPlugins(registry: FlutterPluginRegistry) {
    if (!registry.hasPlugin("FlutterDownloaderPlugin")) {
       FlutterDownloaderPlugin.register(with: registry.registrar(forPlugin: "FlutterDownloaderPlugin")!)
    }
}
