import SwiftUI
import WatchConnectivity
import Security

struct WatchCard: Codable, Identifiable {
    let id: String
    let name: String
    let code: String
    let favorite: Bool
    let width: Int
    let height: Int
    let bits: String
    var valid: Bool {
        !id.isEmpty && code.count <= 256 && width > 0 && width <= 192 &&
        (height == 1 || (height == width && width <= 49)) &&
        bits.count == (width * height + 3) / 4 && bits.allSatisfy { "0123456789abcdef".contains($0) }
    }
}
struct WatchSnapshot: Codable {
    let schema: Int
    let owner: String
    let revision: Int
    let language: String
    let cards: [WatchCard]
    var locallyErased: Bool? = nil
    var allowNewOwner: Bool? = nil
    var valid: Bool { schema == 1 && !owner.isEmpty && revision >= 0 && cards.count <= 12 &&
        Set(cards.map(\.id)).count == cards.count && cards.allSatisfy(\.valid) }
}

final class WatchStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published var snapshot: WatchSnapshot?
    @Published var error = false
    private let key: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "nl.paskluis.watch", kSecAttrAccount as String: "snapshot"]
    override init() {
        super.init()
        var query = key
        query[kSecReturnData as String] = true
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data, let stored = try? JSONDecoder().decode(WatchSnapshot.self, from: data), stored.valid {
            snapshot = stored
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
    var dutch: Bool { snapshot?.language != "en" }
    func text(_ nl: String, _ en: String) -> String { dutch ? nl : en }
    private func persist(_ data: Data) -> Bool {
        let attrs: [String:Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let update = SecItemUpdate(key as CFDictionary, attrs as CFDictionary)
        if update == errSecSuccess { return true }
        guard update == errSecItemNotFound else { return false }
        return SecItemAdd(key.merging(attrs) { _, new in new } as CFDictionary, nil) == errSecSuccess
    }
    func erase(reset: Bool = false) {
        // Preserve revision as a tombstone, so the same cached context cannot resurrect data.
        guard let old = snapshot else { return }
        let empty = WatchSnapshot(schema: 1, owner: old.owner, revision: old.revision, language: old.language, cards: [], locallyErased: true, allowNewOwner: reset)
        guard let data = try? JSONEncoder().encode(empty), persist(data) else { error = true; return }
        snapshot = empty
        try? WCSession.default.updateApplicationContext(["ack": -1, "owner": old.owner])
    }
    private func receive(_ context: [String:Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: context), data.count <= 7000,
              let incoming = try? JSONDecoder().decode(WatchSnapshot.self, from: data), incoming.valid else { return }
        DispatchQueue.main.async {
            if let old = self.snapshot {
                if old.owner != incoming.owner {
                    guard old.allowNewOwner == true else { self.error = true; return }
                } else {
                    if incoming.revision == old.revision && old.locallyErased != true {
                        try? WCSession.default.updateApplicationContext(["ack": old.revision, "owner": old.owner])
                    }
                    guard incoming.revision > old.revision else { return }
                }
            }
            guard self.persist(data) else { self.error = true; return }
            self.snapshot = incoming
            self.error = false
            try? WCSession.default.updateApplicationContext(["ack": incoming.revision, "owner": incoming.owner])
        }
    }
    func reset() { erase(reset: true) }
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if state == .activated { receive(session.receivedApplicationContext) }
    }
    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) { receive(context) }
}

struct CodeView: View {
    let card: WatchCard
    @Environment(\.isLuminanceReduced) private var dimmed
    @Environment(\.displayScale) private var scale
    var body: some View {
        VStack(spacing: 4) {
            Text(card.name).font(.caption).lineLimit(1)
            if dimmed { Image(systemName: "creditcard").font(.largeTitle) }
            else {
                Canvas { context, size in
                    let quiet = card.height == 1 ? 10 : 4
                    let availableW = Int(size.width * scale)
                    let availableH = Int(size.height * scale)
                    let module = min(availableW / (card.width + quiet*2), card.height == 1 ? Int.max : availableH / (card.height + quiet*2))
                    guard module >= 1 else { return }
                    let m = CGFloat(module)/scale
                    let h = card.height == 1 ? floor(size.height * scale * 0.8)/scale : CGFloat(card.height)*m
                    let x0 = floor((size.width-CGFloat(card.width)*m)*scale/2)/scale
                    let y0 = floor((size.height-h)*scale/2)/scale
                    let nibbles = card.bits.compactMap { Int(String($0), radix:16) }
                    for y in 0..<card.height {
                        for x in 0..<card.width {
                            let i = y*card.width+x
                            if nibbles[i/4] & (1 << (3-i%4)) != 0 {
                                let r = CGRect(x:x0+CGFloat(x)*m, y:y0+CGFloat(y)*(card.height == 1 ? h : m), width:m, height:card.height == 1 ? h : m)
                                context.fill(Path(r), with:.color(.black), style: FillStyle(antialiased: false))
                            }
                        }
                    }
                }.background(.white).accessibilityLabel("Barcode")
            }
            Text(card.code).font(.caption2).lineLimit(2).minimumScaleFactor(0.7)
        }.padding(.horizontal, 4).privacySensitive()
    }
}

struct LiveCodeView: View {
    @ObservedObject var store: WatchStore
    let id: String
    var body: some View {
        if let card = store.snapshot?.cards.first(where: { $0.id == id }) {
            CodeView(card: card)
        } else {
            Text(store.text("Dit pasje is verwijderd.", "This card was removed."))
        }
    }
}

@main
struct PasKluisWatchApp: App {
    @StateObject private var store = WatchStore()
    @State private var confirmReset = false
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    if store.snapshot?.cards.isEmpty != false {
                        Text(store.text("Kies pasjes in PasKluis op je iPhone bij Instellingen › Smartwatch.", "Choose cards in PasKluis on your iPhone under Settings › Smartwatch."))
                    }
                    ForEach(store.snapshot?.cards ?? []) { card in
                        NavigationLink { LiveCodeView(store: store, id: card.id) } label: {
                            Label(card.name, systemImage: card.favorite ? "star.fill" : "creditcard")
                        }
                    }
                    if store.error { Text(store.text("Synchronisatie mislukt. Probeer opnieuw of koppel opnieuw.", "Sync failed. Retry or reconnect.")) }
                    Button(store.text("Pasjes wissen", "Erase cards"), role: .destructive) { store.erase() }
                    Button(store.text("Opnieuw koppelen", "Reconnect")) { confirmReset = true }
                }.navigationTitle("PasKluis")
                 .confirmationDialog(store.text("Wis alle pasjes en koppel opnieuw?", "Erase all cards and reconnect?"), isPresented: $confirmReset) {
                    Button(store.text("Wissen en opnieuw koppelen", "Erase and reconnect"), role: .destructive) { store.reset() }
                 }
            }
        }
    }
}
