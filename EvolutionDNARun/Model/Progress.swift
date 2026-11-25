import Foundation

/// 生命体カタログ（Phase 2: 最初の形態群。名称は独自）
enum CreatureCatalog {
    static func name(element: Element, sizeClass: Int) -> String {
        let base: [Element: [String]] = [
            .none: ["Pipyon", "Pipyon Duo", "Grand Pipyon", "Pipyon Colossus"],
            .fire: ["Embrin", "Pyrocub", "Blazewyrm", "Solaris Drake"],
            .ice: ["Frostlet", "Glacimite", "Rimeguard", "Aurora Leviathan"],
            .thunder: ["Zappit", "Voltwing", "Stormraptor", "Tempest Phoenix"],
        ]
        return base[element]?[min(sizeClass, 3)] ?? "Unknown"
    }
}

/// AI社員06: セーブデータ（バージョン付き、破損時は既定値へフォールバック）
struct SaveData: Codable {
    var version = 1
    var currentStage = 1
    var cleared: Set<Int> = []
    var dna = 0
    var discovered: Set<String> = ["none-0"]
    var bgmVolume: Float = 0.55
    var sfxVolume: Float = 0.9
    var haptics = true
    var tutorialDone = false
    var stagesSinceAd = 0
}

@MainActor
final class Progress: ObservableObject {
    static let shared = Progress()
    @Published private(set) var data: SaveData
    private let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("save.json")

    private init() {
        if let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(SaveData.self, from: d), s.version <= 1,
           s.currentStage >= 1, s.dna >= 0 {
            data = s
        } else { data = SaveData() }
        apply()
    }

    func clear(stage: Int, dna: Int, element: Element, sizeClass: Int) {
        let first = !data.cleared.contains(stage)
        data.cleared.insert(stage)
        data.dna += dna
        data.discovered.insert("\(element.rawValue)-\(sizeClass)")
        if first { data.currentStage = max(data.currentStage, stage + 1); data.stagesSinceAd += 1 }
        save()
    }
    func addDNA(_ n: Int) { data.dna += n; save() }
    func spendDNA(_ n: Int) -> Bool { guard data.dna >= n else { return false }; data.dna -= n; save(); return true }
    func resetAdCounter() { data.stagesSinceAd = 0; save() }
    func discover(_ e: Element, _ k: Int) {
        if data.discovered.insert("\(e.rawValue)-\(k)").inserted { save() }
    }
    func setVolumes(bgm: Float, sfx: Float, haptics: Bool) {
        data.bgmVolume = bgm; data.sfxVolume = sfx; data.haptics = haptics; apply(); save()
    }
    func resetAll() { let keep = (data.bgmVolume, data.sfxVolume, data.haptics); data = SaveData(); (data.bgmVolume, data.sfxVolume, data.haptics) = keep; save() }
    func apply() {
        GameSettings.register()
        AudioEngine.shared.muted = GameSettings.muteAll
        AudioEngine.shared.bgmVolume = data.bgmVolume
        AudioEngine.shared.sfxVolume = data.sfxVolume
        Haptics.shared.enabled = data.haptics
    }
    private func save() {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(data) { try? d.write(to: url, options: .atomic) }
    }
}
