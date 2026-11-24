import Foundation

/// プレイヤー設定（UserDefaults 保存。セーブデータとは分離して互換性を保つ）
enum GameSettings {
    private static let d = UserDefaults.standard
    enum Key {
        static let muteAll = "set.muteAll", hapticStrength = "set.hapticStrength", sensitivity = "set.sensitivity"
        static let quality = "set.quality", screenShake = "set.screenShake", reduceFlash = "set.reduceFlash"
        static let shortNumbers = "set.shortNumbers", showTutorialHint = "set.showHint", leftHanded = "set.leftHanded"
        static let batterySaver = "set.batterySaver"
    }
    static func register() {
        d.register(defaults: [Key.muteAll: false, Key.hapticStrength: 1.0, Key.sensitivity: 1.0, Key.quality: 1,
                              Key.screenShake: true, Key.reduceFlash: false, Key.shortNumbers: true,
                              Key.showTutorialHint: true, Key.leftHanded: false, Key.batterySaver: false])
    }
    static var muteAll: Bool { d.bool(forKey: Key.muteAll) }
    static var hapticStrength: Float { Float(d.double(forKey: Key.hapticStrength)) }
    static var sensitivity: Float { Float(d.double(forKey: Key.sensitivity)) }
    /// 0=省電力 1=標準 2=高画質
    static var quality: Int { batterySaver ? 0 : d.integer(forKey: Key.quality) }
    static var screenShake: Bool { d.bool(forKey: Key.screenShake) }
    static var reduceFlash: Bool { d.bool(forKey: Key.reduceFlash) }
    static var shortNumbers: Bool { d.bool(forKey: Key.shortNumbers) }
    static var showHint: Bool { d.bool(forKey: Key.showTutorialHint) }
    static var leftHanded: Bool { d.bool(forKey: Key.leftHanded) }
    static var batterySaver: Bool { d.bool(forKey: Key.batterySaver) }

    /// 1200 → 1.2K, 3400000 → 3.4M
    static func format(_ n: Int) -> String {
        guard shortNumbers, n >= 1000 else { return "\(n)" }
        let (v, s): (Double, String) = n >= 1_000_000 ? (Double(n) / 1_000_000, "M") : (Double(n) / 1000, "K")
        return (v >= 100 ? String(Int(v)) : String(format: "%.1f", v).replacingOccurrences(of: ".0", with: "")) + s
    }
}
