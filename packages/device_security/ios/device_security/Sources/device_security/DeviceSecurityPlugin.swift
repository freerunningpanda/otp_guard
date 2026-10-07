import Flutter
import UIKit

public class DeviceSecurityPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var isProtectionEnabled = false

  // Set while Dart listens to the events channel, nil otherwise.
  private var eventSink: FlutterEventSink?

  // True between willResignActive and didBecomeActive.
  private var isInactive = false

  // The blurs laid over the windows, one per window: the task switcher snapshot of a scene
  // includes all of its windows. Empty while no blur is shown.
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
    // For the whole life of the plugin, not only while Dart listens: the blur follows the screen
    // capture. Events still go out only while a Dart listener exists.
    center.addObserver(
      self,
      selector: #selector(screenCaptureDidChange),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // Fires for every loss of focus, not only for the task switcher: Control Center, an incoming
  // call and system prompts such as Face ID blur the screen too.
  @objc private func applicationWillResignActive() {
    isInactive = true
    updateBlur()
  }

  @objc private func applicationDidBecomeActive() {
    isInactive = false
    updateBlur()
  }

  // The blur is on while protection is on and the app is inactive (the task switcher takes its
  // snapshot then) or the screen is captured by a recording, AirPlay or mirroring: a capture
  // then shows a blur instead of the content.
  private func updateBlur() {
    if isProtectionEnabled && (isInactive || screen()?.isCaptured == true) {
      showBlur()
    } else {
      hideBlur()
    }
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
    // A recording can already be running when Dart subscribes, and no notification will
    // announce it. Report it now so the app does not show codes to someone who started
    // recording before the screen opened.
    if screen()?.isCaptured == true {
      send("screenRecordingChanged", ["isRecording": true])
    }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    // By name: removeObserver(self) would also drop the observers behind the blur. The capture
    // observer stays too: the blur needs it, and without a sink it sends nothing.
    NotificationCenter.default.removeObserver(
      self,
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )
    eventSink = nil
    return nil
  }

  @objc private func userDidTakeScreenshot() {
    send("screenshotTaken")
  }

  @objc private func screenCaptureDidChange(_ notification: Notification) {
    updateBlur()
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
        updateBlur()
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
