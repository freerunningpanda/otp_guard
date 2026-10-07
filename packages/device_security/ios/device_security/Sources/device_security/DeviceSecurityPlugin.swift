import Flutter
import UIKit

public class DeviceSecurityPlugin: NSObject, FlutterPlugin {
  private var isProtectionEnabled = false

  // The blurs laid over the windows while the app is inactive, one per window: the task switcher
  // snapshot of a scene includes all of its windows. Empty while no blur is shown.
  private var blurViews: [UIVisualEffectView] = []

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.freerunningpanda.device_security/methods",
      binaryMessenger: registrar.messenger()
    )
    let instance = DeviceSecurityPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
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
