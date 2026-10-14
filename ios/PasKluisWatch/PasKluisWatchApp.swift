import SwiftUI
import WatchConnectivity
import Security

struct WatchCard: Codable, Identifiable {
    let id: String
    let name: String
    let code: String
    let favorite: Bool
    var category: String? = nil
    var group: String { category ?? "loyalty" }
    let width: Int
    let height: Int
    let bits: String
    var valid: Bool {
        ["loyalty","qr","gift"].contains(group) && !id.isEmpty && code.count <= 256 && width > 0 && width <= 211 &&
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
    var logos: [String:String]? = nil
    var locallyErased: Bool? = nil
    var allowNewOwner: Bool? = nil
    var valid: Bool { schema == 1 && !owner.isEmpty && revision >= 0 &&
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
        guard let data = try? JSONSerialization.data(withJSONObject: context), data.count <= 87000,
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

struct CardRow: View {
    let card: WatchCard
    let logo: String?
    var body: some View {
        HStack {
            Group {
                if let logo, let data = Data(base64Encoded: logo), let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit().padding(4).background(.white)
                } else {
                    Image(systemName: card.group == "qr" ? "qrcode" : card.group == "gift" ? "gift" : "creditcard")
                        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.gray.opacity(0.3))
                }
            }.frame(width: 30, height: 30).clipShape(Circle())
            Text(card.name).lineLimit(2)
        }
    }
}

@main
struct PasKluisWatchApp: App {
    @StateObject private var store = WatchStore()
    @State private var confirmReset = false
    @State private var confirmErase = false
    @State private var category = "loyalty"
    private let groups = ["loyalty", "qr", "gift"]
    func title(_ group: String) -> String {
        switch group {
        case "qr": return store.text("QR-codes", "QR codes")
        case "gift": return store.text("Cadeaukaarten", "Gift cards")
        default: return store.text("Klantenkaarten", "Loyalty cards")
        }
    }
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                VStack(spacing: 2) {
                    Image("PasKluisLogo").resizable().scaledToFit().frame(width: 28, height: 28).clipShape(Circle()).accessibilityLabel("PasKluis")
                    HStack {
                        ForEach(groups, id: \.self) { group in
                            Button { category = group } label: {
                                Image(systemName: group == "qr" ? "qrcode" : group == "gift" ? "gift" : "creditcard")
                                    .frame(maxWidth: .infinity)
                            }.buttonStyle(.plain).foregroundStyle(category == group ? Color.white : Color.gray)
                                .padding(.vertical, 4).background(category == group ? Color.blue.opacity(0.4) : Color.clear)
                                .clipShape(Capsule()).accessibilityLabel(title(group))
                                .accessibilityAddTraits(category == group ? .isSelected : [])
                        }
                    }
                    TabView(selection: $category) {
                        ForEach(groups, id: \.self) { group in
                            List {
                                Text(title(group)).font(.caption).foregroundStyle(.secondary)
                                let cards = (store.snapshot?.cards ?? []).filter { $0.group == group }
                                if cards.isEmpty { Text(store.text("Kies passen in deze categorie op je telefoon.", "Choose cards in this category on your phone.")) }
                                ForEach(cards) { card in
                                    NavigationLink { LiveCodeView(store: store, id: card.id) } label: {
                                        CardRow(card: card, logo: store.snapshot?.logos?[card.id])
                                    }
                                }
                                NavigationLink(store.text("Instellingen", "Settings")) {
                                    List {
                                        if store.error { Text(store.text("Synchronisatie mislukt.", "Sync failed.")) }
                                        Button(store.text("Pasjes wissen", "Erase cards"), role: .destructive) { confirmErase = true }
                                        Button(store.text("Opnieuw koppelen", "Reconnect")) { confirmReset = true }
                                    }
                                }
                            }.tag(group)
                        }
                    }.tabViewStyle(.page(indexDisplayMode: .never))
                }
                .confirmationDialog(store.text("Wis alle passen op dit horloge?", "Erase all cards on this watch?"), isPresented: $confirmErase) {
                    Button(store.text("Wissen", "Erase"), role: .destructive) { store.erase() }
                }
                .confirmationDialog(store.text("Wis alle passen en koppel opnieuw?", "Erase all cards and reconnect?"), isPresented: $confirmReset) {
                    Button(store.text("Wissen en opnieuw koppelen", "Erase and reconnect"), role: .destructive) { store.reset() }
                }
            }
        }
    }
}
