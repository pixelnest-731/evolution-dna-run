import Foundation

/// AI社員05: ゲームロジック（描画と完全分離。論理上の生物数は Int、描画数は別管理）

enum Element: String, Codable, CaseIterable {
    case none, fire, ice, thunder, poison, water, plant, rock, dark, light, cosmic
    /// 3Dモデルで描くキャラ（水・植物・闇・シークレット宇宙・ユニーク光）
    static let hero3D: Set<Element> = [.water, .plant, .dark, .cosmic, .light]
    /// 進化ゲートに出る属性（通常）
    static let playable: [Element] = [.fire, .ice, .thunder, .water, .plant, .dark]
    /// 相棒専用（ゲートでは変わらない特別キャラ）
    var isSpecial: Bool { self == .cosmic || self == .light }

    var displayName: String {
        switch self {
        case .none: return String(localized: "無属性")
        case .fire: return String(localized: "炎")
        case .ice: return String(localized: "氷")
        case .thunder: return String(localized: "雷")
        case .poison: return String(localized: "毒")
        case .water: return String(localized: "水")
        case .plant: return String(localized: "植物")
        case .rock: return String(localized: "岩石")
        case .dark: return String(localized: "闇")
        case .light: return String(localized: "光")
        case .cosmic: return String(localized: "宇宙")
        }
    }
    var symbol: String {
        switch self {
        case .none: return "•"; case .fire: return "🔥"; case .ice: return "❄︎"; case .thunder: return "⚡︎"
        case .poison: return "☠︎"; case .water: return "💧"; case .plant: return "🌿"; case .rock: return "◆"
        case .dark: return "☾"; case .light: return "✦"; case .cosmic: return "✶"
        }
    }
}

enum GateKind: Codable, Equatable {
    case add(Int), sub(Int), mul(Int), div(Int)
    case evolve(Element)
    case fuse

    var label: String {
        switch self {
        case .add(let n): return "+\(n)"
        case .sub(let n): return "−\(n)"
        case .mul(let n): return "×\(n)"
        case .div(let n): return "÷\(n)"
        case .evolve(let e): return e.rawValue.uppercased()
        case .fuse: return "MERGE"
        }
    }
    var isHarmful: Bool {
        if case .sub = self { return true }
        if case .div = self { return true }
        return false
    }
}

struct GateRow: Codable { var z: Float; var left: GateKind; var right: GateKind }
struct ObstacleDef: Codable { var z: Float; var x: Float; var sweep: Float; var kills: Int }

struct BossDef: Codable {
    var name: String
    var hp: Double
    var weakness: Element
    var resist: Element
    var kind: Int = 0
}

/// 道中の小ボス（通り道をふさぐ。仲間の力がHP以上なら撃破、一部の仲間を失う）
struct MiniBossDef: Codable { var z: Float; var afterRow: Int; var boss: BossDef }

struct StageDef: Codable {
    var index: Int
    var seed: UInt64
    var length: Float
    var rows: [GateRow]
    var obstacles: [ObstacleDef]
    var boss: BossDef
    var minis: [MiniBossDef] = []
    /// 10ステージごとのワールドの最後は「大ボス」
    var isWorldBoss: Bool { index % World.size == 0 }
}

/// ワールド（10ステージで1ワールド。最後に大ボス）
enum World {
    static let size = 10
    static let names = ["はじまりの楽園", "ふしぎ細胞の海", "マグマ火山", "こおりの氷河", "カミナリ雲の峰", "ほしぞら宇宙"]
    static let icons = ["leaf.fill", "drop.fill", "flame.fill", "snowflake", "bolt.fill", "sparkles"]
    static func of(_ stage: Int) -> Int { (stage - 1) / size }
    static func name(_ w: Int) -> String { w < names.count ? names[w] : "未知の領域 \(w + 1)" }
    static func icon(_ w: Int) -> String { icons[w % icons.count] }
}

/// 集団の状態。sizeClass: 0=微生物 1=中型 2=大型 3=巨大
struct Swarm: Equatable {
    var count: Int = 1
    var element: Element = .none
    var sizeClass: Int = 0

    static let classPower: [Double] = [1, 12, 150, 1900]   // 融合10体→1体で戦闘力×12（＞×10）
    var unitPower: Double { Swarm.classPower[min(sizeClass, 3)] * (element == .none ? 1 : element == .cosmic ? 2.0 : element == .light ? 1.8 : 1.5) }

    func power(against boss: BossDef) -> Double {
        var p = Double(count) * unitPower
        if element != .none && element == boss.weakness { p *= 2 }
        if element != .none && !element.isSpecial && element == boss.resist { p *= 0.5 }
        return p
    }

    mutating func apply(_ g: GateKind) {
        switch g {
        case .add(let n): count += max(1, n / Int(pow(10.0, Double(sizeClass))))
        case .sub(let n): count -= n
        case .mul(let n): count *= n
        case .div(let n): count /= n
        case .evolve(let e): if !element.isSpecial { element = e }
        case .fuse:
            if count >= 10 && sizeClass < 3 { count /= 10; sizeClass += 1 }
        }
        count = max(0, min(count, 9_999_999))
    }

    /// 障害物は大きさに関係なく一定「体数」を倒す → 融合個体は障害物に強い
    mutating func hit(_ o: ObstacleDef) { count = max(0, count - o.kills) }

    /// 小ボス戦。勝てば true（HPに応じて仲間を一部失う）
    mutating func fight(_ b: BossDef) -> Bool {
        let p = power(against: b)
        guard p >= b.hp, p > 0 else { return false }
        let loss = Int((Double(count) * 0.6 * b.hp / p).rounded(.up))
        count = max(1, count - loss)
        return true
    }
}

// MARK: - 再現可能な乱数
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum StageGenerator {

    static func stage(_ index: Int) -> StageDef {
        if index == 1 { return tutorial }
        var rng = SplitMix64(seed: UInt64(index) &* 0x5DEECE66D &+ 11)
        // 難易度カーブ: 0(序盤)→1(ステージ40以降)
        let t = min(1.0, Double(index - 2) / 38.0)
        // コースは長め：6列(ステージ2)→最大14列。3列ごとに小ボスが道をふさぐ
        let rowCount = min(6 + index / 3, 14)
        var rows: [GateRow] = []
        var miniRows: [Int] = []
        var z: Float = -16
        let evoSlot = Int.random(in: 0..<2, using: &rng)
        // 序盤5ステージは弱点が分かりやすいゴリラ、その後ボスの種類が増える
        let bossKind = index <= 5 ? BossKind.gorilla : BossKind.allCases[(index / 2) % BossKind.allCases.count]
        let weak = bossKind.weakness
        for r in 0..<rowCount {
            var a: GateKind, b: GateKind
            if r == evoSlot || (r == rowCount / 2 + 1 && index >= 12) {
                let others = (index >= 4 ? Element.playable : [Element.fire, .ice, .thunder]).filter { $0 != weak }
                a = .evolve(weak); b = .evolve(others.randomElement(using: &rng)!)
            } else if (r == rowCount - 1 || r == rowCount / 2) && index >= 8 {
                a = .fuse; b = .add(Int.random(in: 3...8, using: &rng) * 10)
            } else {
                let good: [GateKind] = [.add(10), .add(20), .add(50), .mul(2), .mul(3), .mul(5)]
                let bad: [GateKind] = [.sub(10), .sub(20), .div(2)]
                a = good.randomElement(using: &rng)!
                b = Double.random(in: 0..<1, using: &rng) < (index <= 3 ? 0 : 0.1 + 0.25 * t) ? bad.randomElement(using: &rng)! : good.randomElement(using: &rng)!
            }
            if Bool.random(using: &rng) { swap(&a, &b) }
            rows.append(GateRow(z: z, left: a, right: b))
            z -= Float.random(in: 13...17, using: &rng)
            if (r + 1) % 3 == 0 && r < rowCount - 1 { miniRows.append(r); z -= 12 }   // 小ボス用の広場
        }
        var obstacles: [ObstacleDef] = []
        for i in 0..<(rows.count - 1) where index >= 4 && !miniRows.contains(i) && (i % 2 == 1 || index > 12) {
            let mid = (rows[i].z + rows[i + 1].z) / 2
            obstacles.append(ObstacleDef(z: mid, x: Float.random(in: -1.5...1.5, using: &rng),
                                         sweep: index > 10 ? 1.6 : 0, kills: 3 + index / 2))
        }
        let length = z - 10
        var stage = StageDef(index: index, seed: rng.state, length: length, rows: rows, obstacles: obstacles,
                             boss: BossDef(name: bossKind.name, hp: 1, weakness: weak, resist: bossKind.resist, kind: bossKind.rawValue))
        // 小ボス：その地点までの最適ルートの力に対して 15%→40%
        for r in miniRows {
            let k = BossKind.allCases.randomElement(using: &rng)!
            let zMid = (rows[r].z + rows[r + 1].z) / 2
            var m = MiniBossDef(z: zMid, afterRow: r, boss: BossDef(name: k.name, hp: 1, weakness: k.weakness, resist: index <= 8 ? .none : k.resist, kind: k.rawValue))
            // 全ルートの力の分布で決める：序盤はほぼ全ルートで勝てる → 後半は上位半分のルートだけ
            let ps = Solver.powers(stage, rowsUsed: r + 1, against: m.boss)
            m.boss.hp = max(2, (Solver.percentile(ps, 0.05 + 0.3 * t) * (0.6 + 0.25 * t)).rounded())
            stage.minis.append(m)
        }
        // 大ボス：生き残るルートの力の分布で決める。序盤は下位2割のルートでも勝てる → 後半は上位25%のみ。
        // ワールドボスはさらに強い
        let ps = Solver.powers(stage)
        let pct = min(0.92, 0.2 + 0.55 * t + (stage.isWorldBoss ? 0.12 : 0) + Double.random(in: 0...0.05, using: &rng) * t)
        stage.boss.hp = max(8, (Solver.percentile(ps, pct) * (0.75 + 0.2 * t)).rounded())
        return stage
    }

    static let tutorial: StageDef = {
        var s = StageDef(index: 1, seed: 1, length: -112, rows: [
            GateRow(z: -14, left: .add(10), right: .mul(2)),
            GateRow(z: -30, left: .evolve(.fire), right: .evolve(.fire)),
            GateRow(z: -48, left: .mul(2), right: .add(20)),
            GateRow(z: -86, left: .mul(3), right: .add(30)),
        ], obstacles: [],
           boss: BossDef(name: BossKind.gorilla.name, hp: 1, weakness: .fire, resist: .ice, kind: 0),
           minis: [MiniBossDef(z: -67, afterRow: 2, boss: BossDef(name: BossKind.moth.name, hp: 3, weakness: .fire, resist: .ice, kind: BossKind.moth.rawValue))])
        // チュートリアル: 一番弱いルートでも必ず勝てるHP
        s.boss.hp = max(5, (Solver.worstPower(s) * 0.7).rounded())
        return s
    }()
}

/// 全ルート総当たり（行数≤14 → 16384通り）。小ボスで全滅するルートは除外。
/// 障害物は回避可能なため含めない＝上界。
enum Solver {
    /// ルート mask で rowsUsed 列まで進んだ後の群れ（途中の小ボスに負けたら nil）
    static func simulate(_ s: StageDef, mask: Int, rowsUsed: Int) -> Swarm? {
        var sw = Swarm()
        for i in 0..<rowsUsed {
            let r = s.rows[i]
            sw.apply((mask >> i) & 1 == 0 ? r.left : r.right)
            for m in s.minis where m.afterRow == i {
                if !sw.fight(m.boss) { return nil }
            }
        }
        return sw
    }
    static func bestPower(_ s: StageDef, rowsUsed: Int? = nil, against: BossDef? = nil) -> Double {
        let n = rowsUsed ?? s.rows.count
        var best = 0.0
        for mask in 0..<(1 << n) {
            guard let sw = simulate(s, mask: mask, rowsUsed: n) else { continue }
            best = max(best, sw.power(against: against ?? s.boss))
        }
        return best
    }
    /// 生き残るルートの力（昇順）
    static func powers(_ s: StageDef, rowsUsed: Int? = nil, against: BossDef? = nil) -> [Double] {
        let n = rowsUsed ?? s.rows.count
        var out: [Double] = []; out.reserveCapacity(1 << n)
        for mask in 0..<(1 << n) { if let sw = simulate(s, mask: mask, rowsUsed: n) { out.append(sw.power(against: against ?? s.boss)) } }
        return out.sorted()
    }
    static func percentile(_ a: [Double], _ p: Double) -> Double {
        guard !a.isEmpty else { return 1 }
        return a[min(a.count - 1, max(0, Int(Double(a.count - 1) * p)))]
    }
    static func worstPower(_ s: StageDef, rowsUsed: Int? = nil, against: BossDef? = nil) -> Double {
        let n = rowsUsed ?? s.rows.count
        var worst = Double.infinity
        for mask in 0..<(1 << n) {
            worst = min(worst, simulate(s, mask: mask, rowsUsed: n)?.power(against: against ?? s.boss) ?? 0)
        }
        return worst
    }
    static func isClearable(_ s: StageDef) -> Bool { bestPower(s) >= s.boss.hp }
}
