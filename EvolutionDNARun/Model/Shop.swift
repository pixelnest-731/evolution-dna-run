import Foundation
import StoreKit

/// ショップの所持品（チケット・広告削除など）。meta.json とは別保存で旧データ互換を保つ
struct ShopState: Codable {
    var reviveTickets = 0
    var startTickets = 0
    var noAds = false
    var starterBought = false
}

/// 課金アイテム定義。本番は App Store Connect に同じIDで登録が必要（オーナー承認事項）
struct IAPItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let fallbackPrice: String
    let consumable: Bool
    var tag: String? = nil
    var use: String = ""
    static let prefix = "com.pixelnest731.evolutiondnarun."
    static let all: [IAPItem] = [
        IAPItem(id: prefix + "starter", title: "スターターパック", detail: "DNA 3,000 ＋ 金色キャラ2体 ＋ 復活チケット3枚（1回限り）", icon: "star.circle.fill", fallbackPrice: "¥300", consumable: false, tag: "お得", use: "はじめての人向け。大量DNAで強化が進み、レアな金色キャラも図鑑に入ります"),
        IAPItem(id: prefix + "noads", title: "広告削除", detail: "ステージ間の広告が出なくなります（報酬広告は自分で選んで見られます）", icon: "nosign", fallbackPrice: "¥600", consumable: false, use: "クリア後などに自動で流れる広告がなくなり、テンポよく遊べます。一度買えばずっと有効"),
        IAPItem(id: prefix + "dna_s", title: "DNA 500", detail: "少しだけ強化したいときに", icon: "sparkle", fallbackPrice: "¥160", consumable: true, use: "DNAは「強化」で仲間の数・パワーを上げたり、復活チケットを買うのに使います"),
        IAPItem(id: prefix + "dna_m", title: "DNA 1,800", detail: "＋20%おまけ", icon: "sparkles", fallbackPrice: "¥480", consumable: true, tag: "人気", use: "強化を数段階まとめて上げられる量。ボスで詰まったときに"),
        IAPItem(id: prefix + "dna_l", title: "DNA 4,500", detail: "＋50%おまけ", icon: "diamond.fill", fallbackPrice: "¥980", consumable: true, use: "強化をしっかり進めて、先のワールドまで一気に進みたい人に"),
        IAPItem(id: prefix + "dna_xl", title: "DNA 12,000", detail: "＋100%おまけ", icon: "crown.fill", fallbackPrice: "¥2,000", consumable: true, tag: "最大", use: "いちばんお得。強化を大きく進めてゴールの神殿を目指せます"),
        IAPItem(id: prefix + "gold", title: "金色キャラ確定ボックス", detail: "金色キャラ1体確定 ＋ DNA 300（全種コンプ済みの場合はDNA 800）", icon: "seal.fill", fallbackPrice: "¥250", consumable: true, use: "金色キャラは図鑑に加わるレアな仲間。集めるほど図鑑がうまります"),
    ]
}

/// DNAで買えるアイテム
struct DNAItem: Identifiable {
    let id: String, title: String, detail: String, icon: String, cost: Int
    var use: String = ""
    static let all: [DNAItem] = [
        DNAItem(id: "revive", title: "復活チケット", detail: "負けた時に広告なしで復活", icon: "heart.fill", cost: 250, use: "ステージで負けても、その場から続きをプレイできます"),
        DNAItem(id: "start", title: "仲間2倍チケット", detail: "次のステージを仲間2倍でスタート", icon: "person.3.fill", cost: 120, use: "スタート時の仲間が2倍。ボス戦や苦手なステージの前に使うと効果大"),
        DNAItem(id: "revive5", title: "復活チケット ×5", detail: "まとめ買いで20%お得", icon: "heart.circle.fill", cost: 1000, use: "1枚あたり200 DNA。よく負けるステージがあるならこちら"),
    ]
}

@MainActor
final class Shop: ObservableObject {
    static let shared = Shop()
    @Published private(set) var s: ShopState
    @Published private(set) var products: [String: Product] = [:]
    @Published var busy = false
    @Published var message: String?
    private let key = "shop.state"
    private var updates: Task<Void, Never>?

    private init() {
        if let raw = UserDefaults.standard.data(forKey: key), let v = try? JSONDecoder().decode(ShopState.self, from: raw) { s = v } else { s = ShopState() }
        updates = Task { [weak self] in
            for await r in Transaction.updates { await self?.handle(r) }
        }
        Task { await load() }
    }
    private func save() { if let raw = try? JSONEncoder().encode(s) { UserDefaults.standard.set(raw, forKey: key) } }

    // MARK: チケット
    func useStartTicket() -> Bool { guard s.startTickets > 0 else { return false }; s.startTickets -= 1; save(); return true }
    func useReviveTicket() -> Bool { guard s.reviveTickets > 0 else { return false }; s.reviveTickets -= 1; save(); return true }
    func buy(_ item: DNAItem) -> Bool {
        guard Progress.shared.spendDNA(item.cost) else { return false }
        switch item.id {
        case "revive": s.reviveTickets += 1
        case "revive5": s.reviveTickets += 5
        case "start": s.startTickets += 1
        default: break
        }
        save(); return true
    }

    // MARK: StoreKit 2
    func load() async {
        do {
            let ps = try await Product.products(for: IAPItem.all.map(\.id))
            products = Dictionary(uniqueKeysWithValues: ps.map { ($0.id, $0) })
        } catch { products = [:] }
    }
    func price(_ i: IAPItem) -> String { products[i.id]?.displayPrice ?? i.fallbackPrice }
    func owned(_ i: IAPItem) -> Bool {
        (i.id.hasSuffix("starter") && s.starterBought) || (i.id.hasSuffix("noads") && s.noAds)
    }
    var available: Bool { !products.isEmpty }

    func purchase(_ i: IAPItem) async {
        guard let p = products[i.id] else { message = AppLinks.storeUnavailableNote; return }
        busy = true; defer { busy = false }
        do {
            switch try await p.purchase() {
            case .success(let r): await handle(r)
            case .pending: message = "購入の承認待ちです"
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = "購入に失敗しました" }
    }

    private func handle(_ r: VerificationResult<Transaction>) async {
        guard case .verified(let t) = r else { return }
        if t.revocationDate == nil { grant(t.productID) }
        await t.finish()
    }

    func restore() async {
        busy = true; defer { busy = false }
        try? await AppStore.sync()
        var n = 0
        for await r in Transaction.currentEntitlements {
            if case .verified(let t) = r, t.revocationDate == nil { grant(t.productID, restoring: true); n += 1 }
        }
        message = n > 0 ? "購入を復元しました" : "復元できる購入はありません"
    }

    private func grant(_ id: String, restoring: Bool = false) {
        let short = id.replacingOccurrences(of: IAPItem.prefix, with: "")
        var gift = ""
        switch short {
        case "starter":
            guard !s.starterBought else { return }
            s.starterBought = true; s.reviveTickets += 3; Progress.shared.addDNA(3000)
            let a = Meta.shared.grantShiny(), b = Meta.shared.grantShiny()
            gift = "DNA 3,000 ＋ " + [a, b].compactMap { $0 }.joined(separator: "・")
        case "noads": s.noAds = true; gift = "広告削除"
        case "dna_s": Progress.shared.addDNA(500); gift = "DNA 500"
        case "dna_m": Progress.shared.addDNA(1800); gift = "DNA 1,800"
        case "dna_l": Progress.shared.addDNA(4500); gift = "DNA 4,500"
        case "dna_xl": Progress.shared.addDNA(12000); gift = "DNA 12,000"
        case "gold":
            Progress.shared.addDNA(300)
            if let g = Meta.shared.grantShiny() { gift = g + " ＋ DNA 300" } else { Progress.shared.addDNA(500); gift = "DNA 800（金色キャラはコンプ済み）" }
        default: return
        }
        save()
        if !restoring { message = "ありがとうございます！\n\(gift) を受け取りました"; AudioEngine.shared.play("win") }
    }
}
