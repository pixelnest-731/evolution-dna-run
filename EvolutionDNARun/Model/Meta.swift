import Foundation
import SwiftUI

/// ハマり要素（ログボ・デイリーミッション・宝箱・強化・図鑑報酬・ボスラッシュ）の状態。
/// SaveData とは別ファイル保存（旧セーブとの互換性維持）。
struct MetaData: Codable {
    var lastLoginDay = ""
    var loginStreak = 0
    var loginClaimedDay = ""
    var missionDay = ""
    var missionProgress: [String: Int] = [:]
    var missionClaimed: Set<String> = []
    var upgrades: [String: Int] = [:]
    var lastFreeChest: Date = .distantPast
    var chestsOpened = 0
    var shiny: Set<String> = []
    var collectionRewards: Set<String> = []
    var bossRushBest = 0
    var adRevivesToday = 0
    var lastInterstitial: Date = .distantPast
}

enum MissionEvent: String { case gate, evolve, fuse, bossWin, dna, play }

struct Mission: Identifiable {
    let id: String, event: MissionEvent, goal: Int, reward: Int, title: String
}

struct Upgrade: Identifiable {
    let id: String, title: String, detail: String, icon: String, maxLevel: Int
    func cost(_ lv: Int) -> Int { 60 + lv * lv * 25 + lv * 40 }
}

@MainActor
final class Meta: ObservableObject {
    static let shared = Meta()
    @Published private(set) var d: MetaData
    private let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("meta.json")

    private init() {
        if let raw = try? Data(contentsOf: url), let m = try? JSONDecoder().decode(MetaData.self, from: raw) { d = m } else { d = MetaData() }
        Meta.shinyKeys = d.shiny
        rollDay()
    }
    nonisolated(unsafe) static var shinyKeys: Set<String> = []
    private func save() {
        Meta.shinyKeys = d.shiny
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let raw = try? JSONEncoder().encode(d) { try? raw.write(to: url, options: .atomic) }
    }
    static func dayKey(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date); return "\(c.year!)-\(c.month!)-\(c.day!)"
    }

    // MARK: ログインボーナス（7日周期。7日目はレアキャラ確定）
    static let loginRewards = [30, 40, 60, 80, 100, 150, 300]
    var loginAvailable: Bool { d.loginClaimedDay != Meta.dayKey() }
    var loginDayIndex: Int { max(0, d.loginStreak - 1) % 7 }
    private func rollDay() {
        let today = Meta.dayKey()
        if d.lastLoginDay != today {
            let yesterday = Meta.dayKey(Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
            d.loginStreak = d.lastLoginDay == yesterday ? d.loginStreak + 1 : 1
            d.lastLoginDay = today
        }
        if d.missionDay != today { d.missionDay = today; d.missionProgress = [:]; d.missionClaimed = []; d.adRevivesToday = 0 }
        save()
    }
    /// 返り値: 受け取ったDNA と レアキャラ名（7日目）
    @discardableResult
    func claimLogin(doubled: Bool) -> (Int, String?) {
        guard loginAvailable else { return (0, nil) }
        let amount = Meta.loginRewards[loginDayIndex] * (doubled ? 2 : 1)
        d.loginClaimedDay = Meta.dayKey()
        Progress.shared.addDNA(amount)
        var rare: String?
        if loginDayIndex == 6 { rare = grantShiny() }
        save(); return (amount, rare)
    }

    // MARK: デイリーミッション
    var missions: [Mission] {
        let pool: [Mission] = [
            Mission(id: "evolve", event: .evolve, goal: 3, reward: 80, title: "進化を3回する"),
            Mission(id: "boss", event: .bossWin, goal: 3, reward: 120, title: "ボスを3体倒す"),
            Mission(id: "gate", event: .gate, goal: 25, reward: 60, title: "ゲートを25回くぐる"),
            Mission(id: "fuse", event: .fuse, goal: 2, reward: 100, title: "融合を2回する"),
            Mission(id: "dna", event: .dna, goal: 30, reward: 70, title: "コースのDNAを30個集める"),
            Mission(id: "play", event: .play, goal: 5, reward: 50, title: "5回プレイする"),
        ]
        var rng = SplitMix64(seed: UInt64(abs(d.missionDay.hashValue == 0 ? 1 : d.missionDay.unicodeScalars.reduce(7) { $0 &* 31 &+ Int($1.value) })))
        return Array(pool.shuffled(using: &rng).prefix(3))
    }
    func progress(_ m: Mission) -> Int { min(m.goal, d.missionProgress[m.id] ?? 0) }
    func track(_ e: MissionEvent, _ n: Int = 1) {
        rollDay()
        for m in missions where m.event == e { d.missionProgress[m.id, default: 0] += n }
        save()
    }
    var unclaimedMissions: Int { missions.filter { progress($0) >= $0.goal && !d.missionClaimed.contains($0.id) }.count }
    func claimMission(_ m: Mission, doubled: Bool) {
        guard progress(m) >= m.goal, !d.missionClaimed.contains(m.id) else { return }
        d.missionClaimed.insert(m.id); Progress.shared.addDNA(m.reward * (doubled ? 2 : 1)); save()
    }

    // MARK: 強化（負けても少しずつ強くなれる）
    static let upgradeList = [
        Upgrade(id: "start", title: "スタート仲間", detail: "最初から仲間が増える", icon: "person.3.fill", maxLevel: 20),
        Upgrade(id: "power", title: "攻撃力", detail: "ボスへのダメージ +8%", icon: "bolt.fill", maxLevel: 25),
        Upgrade(id: "dna", title: "DNA収集", detail: "クリア報酬 +10%", icon: "sparkles", maxLevel: 15),
    ]
    func level(_ id: String) -> Int { d.upgrades[id] ?? 0 }
    var startCount: Int { 1 + level("start") * 2 }
    var powerMultiplier: Double { 1 + Double(level("power")) * 0.08 }
    var dnaMultiplier: Double { 1 + Double(level("dna")) * 0.1 }
    func buy(_ u: Upgrade) -> Bool {
        let lv = level(u.id); guard lv < u.maxLevel, Progress.shared.spendDNA(u.cost(lv)) else { return false }
        d.upgrades[u.id] = lv + 1; save(); return true
    }

    // MARK: 宝箱（4時間ごとに無料、DNAで購入、広告でもう1個）
    static let chestCost = 150
    static let freeInterval: TimeInterval = 4 * 3600
    var freeChestReady: Bool { Date().timeIntervalSince(d.lastFreeChest) >= Meta.freeInterval }
    var freeChestRemaining: TimeInterval { max(0, Meta.freeInterval - Date().timeIntervalSince(d.lastFreeChest)) }
    enum ChestPay { case free, dna, ad }
    struct ChestResult { let dna: Int; let shiny: String?; let upgrade: String? }
    func openChest(_ pay: ChestPay) -> ChestResult? {
        switch pay {
        case .free: guard freeChestReady else { return nil }; d.lastFreeChest = Date()
        case .dna: guard Progress.shared.spendDNA(Meta.chestCost) else { return nil }
        case .ad: break
        }
        d.chestsOpened += 1
        let roll = Int.random(in: 0..<100)
        var result: ChestResult
        // 10回目ごとにレア確定（天井）
        if roll < 8 || d.chestsOpened % 10 == 0, let s = grantShiny() {
            result = ChestResult(dna: 50, shiny: s, upgrade: nil)
        } else if roll < 25, let u = Meta.upgradeList.filter({ level($0.id) < $0.maxLevel }).randomElement() {
            d.upgrades[u.id] = level(u.id) + 1; result = ChestResult(dna: 40, shiny: nil, upgrade: u.title)
        } else {
            result = ChestResult(dna: [60, 80, 100, 150, 250].randomElement()!, shiny: nil, upgrade: nil)
        }
        Progress.shared.addDNA(result.dna); save(); return result
    }
    /// 色違い（金色）キャラを付与。返り値は表示名
    func grantShiny() -> String? {
        let all = (Element.playable + [.none]).flatMap { e in (0..<4).map { (e, $0) } }
        guard let (e, k) = all.filter({ !d.shiny.contains("\($0.0.rawValue)-\($0.1)") }).randomElement() else { return nil }
        d.shiny.insert("\(e.rawValue)-\(k)")
        return "金色の" + CreatureCatalog.name(element: e, sizeClass: k)
    }
    func isShiny(_ e: Element, _ k: Int) -> Bool { d.shiny.contains("\(e.rawValue)-\(k)") }

    // MARK: 図鑑報酬（進化ライン4段階コンプでボーナス）
    func collectionReward(_ e: Element) -> Int? {
        let key = e.rawValue
        guard !d.collectionRewards.contains(key),
              (0..<4).allSatisfy({ Progress.shared.data.discovered.contains("\(e.rawValue)-\($0)") }) else { return nil }
        return 300
    }
    func claimCollection(_ e: Element) {
        guard let r = collectionReward(e) else { return }
        d.collectionRewards.insert(e.rawValue); Progress.shared.addDNA(r); save()
    }

    // MARK: ボスラッシュ
    func recordBossRush(_ streak: Int) { if streak > d.bossRushBest { d.bossRushBest = streak; save() } }

    // MARK: 広告の頻度管理
    var canAdRevive: Bool { d.adRevivesToday < 10 }
    func usedAdRevive() { d.adRevivesToday += 1; save() }
    /// インタースティシャル：ステージ6以降・3クリアごと・前回から90秒以上
    func shouldShowInterstitial(stage: Int) -> Bool {
        guard !Shop.shared.s.noAds, stage >= 6, Progress.shared.data.stagesSinceAd >= 3, Date().timeIntervalSince(d.lastInterstitial) > 90 else { return false }
        d.lastInterstitial = Date(); Progress.shared.resetAdCounter(); save(); return true
    }
}

/// 次のプレイに引き継ぐ一時ブースト（広告視聴など）
enum RunBoost {
    static var startMultiplier = 1
    static var bossRush: Int? = nil   // ボスラッシュ中の連勝数
}
