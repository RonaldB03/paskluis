import Flutter
import UIKit
import UserNotifications
import firebase_messaging
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let giftStoreReminders = GiftStoreReminders()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(name: "nl.paskluis.app/gift-store-reminders", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard let monitor = self?.giftStoreReminders else { result(nil); return }
      switch call.method {
      case "status": result(monitor.status)
      case "requestAlways": monitor.requestAlways(); result(nil)
      case "replace":
        let args = call.arguments as? [String: Any]
        monitor.replace(args?["regions"] as? [[String: Any]] ?? [])
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
}


/// Region monitoring wakes the app without continuous GPS or server requests.
/// Prefix isolation keeps other location/notification users untouched.
private final class GiftStoreReminders: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private let defaults = UserDefaults.standard
  private let key = "paskluis.giftRegions.v1"
  private let prefix = "paskluis.gift."
  private var rows: [String: [String: Any]] = [:]

  override init() {
    super.init()
    rows = defaults.dictionary(forKey: key) as? [String: [String: Any]] ?? [:]
    manager.delegate = self
  }

  var status: String {
    guard CLLocationManager.locationServicesEnabled(), CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return "unavailable" }
    switch manager.authorizationStatus {
    case .authorizedAlways: return "always"
    case .authorizedWhenInUse: return "whenInUse"
    case .denied, .restricted: return "denied"
    default: return "notDetermined"
    }
  }

  func requestAlways() { manager.requestAlwaysAuthorization() }

  func replace(_ incoming: [[String: Any]]) {
    var next: [String: [String: Any]] = [:]
    for row in incoming.prefix(20) {
      guard let id = row["id"] as? String, !id.isEmpty,
            let lat = row["latitude"] as? Double, lat.isFinite, abs(lat) <= 90,
            let lon = row["longitude"] as? Double, lon.isFinite, abs(lon) <= 180,
            let until = row["validUntil"] as? Double, until > Date().timeIntervalSince1970,
            row["body"] is String else { continue }
      next[prefix + id] = row
    }
    let removed = Set(rows.keys).subtracting(next.keys)
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Array(removed))
    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: Array(removed))
    rows = next
    defaults.set(rows, forKey: key)
    reconcile()
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { reconcile() }

  private func reconcile() {
    let allowed = status == "always"
    for region in manager.monitoredRegions where region.identifier.hasPrefix(prefix) {
      if !allowed || rows[region.identifier] == nil { manager.stopMonitoring(for: region) }
    }
    guard allowed else { return }
    let active = Set(manager.monitoredRegions.map { $0.identifier })
    for (id, row) in rows where !active.contains(id) {
      guard let lat = row["latitude"] as? Double, let lon = row["longitude"] as? Double else { continue }
      let region = CLCircularRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lon), radius: 100, identifier: id)
      region.notifyOnEntry = true
      region.notifyOnExit = false
      manager.startMonitoring(for: region)
    }
  }

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    guard region.identifier.hasPrefix(prefix), status == "always",
          let row = rows[region.identifier],
          let until = row["validUntil"] as? Double,
          let body = row["body"] as? String else { return }
    let now = Date().timeIntervalSince1970
    guard now < until else { manager.stopMonitoring(for: region); return }
    let cooldownKey = "paskluis.giftLast." + region.identifier
    let last = defaults.double(forKey: cooldownKey)
    guard last == 0 || (now >= last && now - last >= 24 * 60 * 60) else { return }
    // Reserve before asynchronous delivery to suppress duplicate callbacks.
    defaults.set(now, forKey: cooldownKey)
    let content = UNMutableNotificationContent()
    content.title = row["title"] as? String ?? "PasKluis"
    content.body = body
    content.sound = .default
    // Match the installed flutter_local_notifications Darwin payload so the
    // existing delegate displays foreground alerts and forwards notification taps.
    content.userInfo = ["payload": "gift_store", "NotificationId": 1900000001,
                        "presentAlert": true, "presentSound": true,
                        "presentBadge": false, "presentBanner": true,
                        "presentList": true]
    let request = UNNotificationRequest(identifier: region.identifier, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { [weak self] error in
      if error != nil { self?.defaults.set(last, forKey: cooldownKey) }
    }
  }
}
