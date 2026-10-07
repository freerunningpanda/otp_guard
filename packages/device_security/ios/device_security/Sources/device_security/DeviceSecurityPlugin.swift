import Flutter
import UIKit

public class DeviceSecurityPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var isProtectionEnabled = false

  // Set while Dart listens to the events channel, nil otherwise.
  private var eventSink: FlutterEventSink?

  // The blurs laid over the windows while the app is inactive, one per window: the task switcher
  // snapshot of a scene includes all of its windows. Empty while no blur is shown.
  private var blurViews: [UIVisualEffectView] = []

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.freerunningpanda.device_security/methods",
      binaryMessenger: registrar.messenger()
    )
    let eventChannel = FlutterEventChannel(
      name: "com.freerunningpanda.device_security/events",
      binaryMessenger: registrar.messenger()
    )
    let instance = DeviceSecurityPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    eventChannel.setStreamHandler(instance)
  }

  public override init() {
    super.init()
    // Notifications instead of the FlutterPlugin application delegate callbacks: an app that
    // uses UIScene gets scene callbacks, and UIKit no longer calls applicationWillResignActive.
    let center = NotificationCenter.default
    center.addObserver(
      self,
      selector: #selector(applicationWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // Fires for every loss of focus, not only for the task switcher: Control Center, an incoming
  // call and system prompts such as Face ID blur the screen too.
  @objc private func applicationWillResignActive() {
    if isProtectionEnabled {
      showBlur()
    }
  }

  @objc private func applicationDidBecomeActive() {
    hideBlur()
  }

  private func showBlur() {
    guard blurViews.isEmpty else { return }
    blurViews = windows().map { window in
      let view = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
      view.frame = window.bounds
      view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      window.addSubview(view)
      return view
    }
  }

  private func hideBlur() {
    blurViews.forEach { $0.removeFromSuperview() }
    blurViews = []
  }

  private func windows() -> [UIWindow] {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .filter { !$0.isHidden }
  }

  // The screen comes from a window scene: UIScreen.main is deprecated since iOS 16.
  private func screen() -> UIScreen? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first?.screen
  }

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    let center = NotificationCenter.default
    center.addObserver(
      self,
      selector: #selector(userDidTakeScreenshot),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(screenCaptureDidChange),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    // A recording can already be running when Dart subscribes, and no notification will
    // announce it. Report it now so the app does not show codes to someone who started
    // recording before the screen opened.
    if screen()?.isCaptured == true {
      send("screenRecordingChanged", ["isRecording": true])
    }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    // By name: removeObserver(self) would also drop the observers behind the blur.
    let center = NotificationCenter.default
    center.removeObserver(
      self,
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )
    center.removeObserver(
      self,
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    eventSink = nil
    return nil
  }

  @objc private func userDidTakeScreenshot() {
    send("screenshotTaken")
  }

  @objc private func screenCaptureDidChange(_ notification: Notification) {
    guard let source = (notification.object as? UIScreen) ?? screen() else { return }
    send("screenRecordingChanged", ["isRecording": source.isCaptured])
  }

  private func send(_ type: String, _ fields: [String: Any] = [:]) {
    var event = fields
    event["type"] = type
    event["timestamp"] = Int(Date().timeIntervalSince1970 * 1000)
    eventSink?(event)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setScreenProtection":
      if let args = call.arguments as? [String: Any],
         let enabled = args["enabled"] as? Bool {
        isProtectionEnabled = enabled
        if !enabled {
          hideBlur()
        }
        result(nil)
      } else {
        result(FlutterError(
          code: "INVALID_ARGUMENT",
          message: "Argument 'enabled' (bool) is required",
          details: nil
        ))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
