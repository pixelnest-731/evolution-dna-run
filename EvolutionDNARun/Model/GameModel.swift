import Foundation

/// AI社員05: ゲームロジック（描画と完全分離。論理上の生物数は Int、描画数は別管理）

enum Element: String, Codable, CaseIterable {
    case none, fire, ice, thunder, poison, water, plant, rock, dark, light, cosmic

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

struct StageDef: Codable {
    var index: Int
    var seed: UInt64
    var length: Float
    var rows: [GateRow]
    var obstacles: [ObstacleDef]
    var boss: BossDef
}

/// 集団の状態。sizeClass: 0=微生物 1=中型 2=大型 3=巨大
struct Swarm: Equatable {
    var count: Int = 1
    var element: Element = .none
    var sizeClass: Int = 0

    static let classPower: [Double] = [1, 12, 150, 1900]   // 融合10体→1体で戦闘力×12（＞×10）
    var unitPower: Double { Swarm.classPower[min(sizeClass, 3)] * (element == .none ? 1 : 1.5) }

    func power(against boss: BossDef) -> Double {
        var p = Double(count) * unitPower
        if element != .none && element == boss.weakness { p *= 2 }
        if element != .none && element == boss.resist { p *= 0.5 }
        return p
    }

    mutating func apply(_ g: GateKind) {
        switch g {
        case .add(let n): count += max(1, n / Int(pow(10.0, Double(sizeClass))))
        case .sub(let n): count -= n
        case .mul(let n): count *= n
        case .div(let n): count /= n
        case .evolve(let e): element = e
        case .fuse:
            if count >= 10 && sizeClass < 3 { count /= 10; sizeClass += 1 }
        }
        count = max(0, min(count, 9_999_999))
    }

    /// 障害物は大きさに関係なく一定「体数」を倒す → 融合個体は障害物に強い
    mutating func hit(_ o: ObstacleDef) { count = max(0, count - o.kills) }
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
        let rowCount = min(4 + index / 4, 8)
        var rows: [GateRow] = []
        var z: Float = -16
        let evoSlot = Int.random(in: 1..<max(2, rowCount - 1), using: &rng)
        let bossKind = BossKind.allCases[(index / 2) % BossKind.allCases.count]
        let weak = bossKind.weakness
        for r in 0..<rowCount {
            var a: GateKind, b: GateKind
            if r == evoSlot {
                let others = [Element.fire, .ice, .thunder].filter { $0 != weak }
                a = .evolve(weak); b = .evolve(others.randomElement(using: &rng)!)
            } else if r == rowCount - 1 && index >= 3 {
                a = .fuse; b = .add(Int.random(in: 3...8, using: &rng) * 10)
            } else {
                let good: [GateKind] = [.add(10), .add(20), .add(50), .mul(2), .mul(3), .mul(5)]
                let bad: [GateKind] = [.sub(10), .sub(20), .div(2)]
                a = good.randomElement(using: &rng)!
                b = Int.random(in: 0..<10, using: &rng) < 3 ? bad.randomElement(using: &rng)! : good.randomElement(using: &rng)!
            }
            if Bool.random(using: &rng) { swap(&a, &b) }
            rows.append(GateRow(z: z, left: a, right: b))
            z -= Float.random(in: 13...17, using: &rng)
        }
        var obstacles: [ObstacleDef] = []
        for i in 0..<(rows.count - 1) where i % 2 == 1 || index > 6 {
            let mid = (rows[i].z + rows[i + 1].z) / 2
            obstacles.append(ObstacleDef(z: mid, x: Float.random(in: -1.5...1.5, using: &rng),
                                         sweep: index > 4 ? 1.6 : 0, kills: 5 + index))
        }
        let length = z - 10
        var stage = StageDef(index: index, seed: rng.state, length: length, rows: rows, obstacles: obstacles,
                             boss: BossDef(name: bossKind.name, hp: 1, weakness: weak, resist: bossKind.resist, kind: bossKind.rawValue))
        // 最適解の 55〜70% を HP に設定：クリア可能だが、大きい数字を選ぶだけでは届かない
        let best = Solver.bestPower(stage)
        stage.boss.hp = max(8, (best * Double.random(in: 0.55...0.7, using: &rng)).rounded())
        return stage
    }

    static let tutorial: StageDef = {
        var s = StageDef(index: 1, seed: 1, length: -92, rows: [
            GateRow(z: -14, left: .add(10), right: .mul(2)),
            GateRow(z: -28, left: .mul(3), right: .sub(5)),
            GateRow(z: -44, left: .evolve(.fire), right: .evolve(.ice)),
            GateRow(z: -60, left: .add(20), right: .mul(5)),
            GateRow(z: -76, left: .mul(2), right: .add(30)),
        ], obstacles: [ObstacleDef(z: -52, x: 1.2, sweep: 0, kills: 6)],
           boss: BossDef(name: BossKind.gorilla.name, hp: 1, weakness: .fire, resist: .ice, kind: 0))
        s.boss.hp = (Solver.bestPower(s) * 0.4).rounded()
        return s
    }()
}

/// 全ルート総当たり（行数≤8 → 256通り）。障害物は回避可能なため含めない＝上界、
/// 加えて「全障害物に当たる」最悪ケースでのクリア可能性も検証する。
enum Solver {
    static func bestPower(_ s: StageDef, hitAllObstacles: Bool = false) -> Double {
        var best = 0.0
        for mask in 0..<(1 << s.rows.count) {
            var sw = Swarm()
            var events: [(Float, (inout Swarm) -> Void)] = []
            for (i, r) in s.rows.enumerated() {
                let g = (mask >> i) & 1 == 0 ? r.left : r.right
                events.append((r.z, { $0.apply(g) }))
            }
            if hitAllObstacles { for o in s.obstacles { events.append((o.z, { $0.hit(o) })) } }
            for e in events.sorted(by: { $0.0 > $1.0 }) { e.1(&sw) }
            best = max(best, sw.power(against: s.boss))
        }
        return best
    }
    static func isClearable(_ s: StageDef) -> Bool { bestPower(s) >= s.boss.hp }
}
