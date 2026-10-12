import Flutter
import WatchConnectivity

/// No card data in UserDefaults. WCSession owns the pending encrypted transport.
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()
    private var channel: FlutterMethodChannel?
    private let defaults = UserDefaults.standard
    private let garmin = PKGarminBridge()
    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    func register(_ messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "nl.paskluis.app/watches", binaryMessenger: messenger)
        garmin.changed = { [weak self] in self?.changed() }
        channel?.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            switch call.method {
            case "status":
                self.activate()
                let pending = self.defaults.object(forKey: "watch.apple.pending") as? Int ?? -1
                let ack = self.defaults.integer(forKey: "watch.apple.ack")
                result(["apple": ["confirmed": pending >= 0 && pending == ack &&
                    self.defaults.string(forKey: "watch.apple.ackOwner") == self.defaults.string(forKey: "watch.apple.owner"),
                    "installed": self.session?.isWatchAppInstalled ?? false],
                    "garmin": self.garmin.status(), "garminDevices": self.garmin.devices()])
            case "chooseGarmin": self.garmin.choose(); result(nil)
            case "forgetGarmin": self.garmin.forget(); result(nil)
            case "setGarmin":
                let id = (call.arguments as? [String: Any])?["id"] as? String ?? ""
                if self.garmin.selectDevice(id) { result(nil) }
                else { result(FlutterError(code: "device", message: "Clear the previous watch first", details: nil)) }
            case "replace":
                guard let args = call.arguments as? [String:Any],
                      let raw = args["snapshot"] as? String, let data = raw.data(using: .utf8), data.count <= 7000,
                      let snapshot = try? JSONSerialization.jsonObject(with: data) as? [String:Any] else {
                    result(FlutterError(code: "snapshot", message: "Invalid snapshot", details: nil)); return
                }
                if args["target"] as? String == "garmin" {
                    self.garmin.replace(snapshot) { success in
                        DispatchQueue.main.async { result(success ? nil : FlutterError(code: "connection", message: "Open Garmin app", details: nil)) }
                    }
                    return
                }
                guard args["target"] as? String == "apple" else {
                    result(FlutterError(code: "target", message: "Unsupported watch", details: nil)); return
                }
                self.defaults.set(snapshot["revision"], forKey: "watch.apple.pending")
                self.defaults.set(snapshot["owner"], forKey: "watch.apple.owner")
                guard args["target"] as? String == "apple", let session = self.session,
                      session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else {
                    result(FlutterError(code: "connection", message: "Install and open the watch app", details: nil)); return
                }
                do { try session.updateApplicationContext(snapshot); result(nil) }
                catch { result(FlutterError(code: "connection", message: "Could not queue snapshot", details: nil)) }
            default: result(FlutterMethodNotImplemented)
            }
        }
    }

    private func activate() {
        guard let session = session, session.delegate == nil else { return }
        session.delegate = self
        session.activate()
    }
    private func changed() { DispatchQueue.main.async { self.channel?.invokeMethod("changed", arguments: nil) } }
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) { changed() }
    func sessionDidBecomeInactive(_ session: WCSession) { defaults.removeObject(forKey: "watch.apple.ack"); changed() }
    func sessionDidDeactivate(_ session: WCSession) { session.activate(); changed() }
    func sessionWatchStateDidChange(_ session: WCSession) { changed() }
    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        if let ack = context["ack"] as? Int, let owner = context["owner"] as? String {
            defaults.set(ack, forKey: "watch.apple.ack")
            defaults.set(owner, forKey: "watch.apple.ackOwner")
            changed()
        }
    }
}
