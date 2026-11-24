import AVFoundation
import CoreHaptics
import UIKit

/// AI社員09: AVAudioEngine による SFX ボイスプール + 3ステムのダイナミックBGM
final class AudioEngine {
    static let shared = AudioEngine()
    private let engine = AVAudioEngine()
    private let sfxMix = AVAudioMixerNode()
    private let bgmMix = AVAudioMixerNode()
    private var voices: [AVAudioPlayerNode] = []
    private var nextVoice = 0
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var stems: [AVAudioPlayerNode] = []
    private var stemTarget: [Float] = [1, 0, 0]
    private var fadeTimer: Timer?
    private var lastPlay: [String: CFTimeInterval] = [:]
    var popSet = "a"
    var comboStep = 0

    var sfxVolume: Float = 0.9 { didSet { sfxMix.outputVolume = sfxVolume } }
    var bgmVolume: Float = 0.55 { didSet { bgmMix.outputVolume = bgmVolume } }

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        engine.attach(sfxMix); engine.attach(bgmMix)
        engine.connect(sfxMix, to: engine.mainMixerNode, format: nil)
        engine.connect(bgmMix, to: engine.mainMixerNode, format: nil)
        let names = ["gate_mul", "gate_big", "gate_bad", "evolve", "fuse", "hit", "obstacle", "boss_roar", "boss_down", "win", "tap", "boss_hit", "boss_stagger", "shatter", "boss_fall",
                     "bgm_micro_base", "bgm_micro_arp", "bgm_micro_drums"]
            + (0..<8).flatMap { i in ["a", "b", "c"].map { "pop_\($0)_\(i)" } }
        for n in names {
            guard let url = Bundle.main.url(forResource: n, withExtension: "wav"),
                  let f = try? AVAudioFile(forReading: url),
                  let b = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: AVAudioFrameCount(f.length)) else { continue }
            try? f.read(into: b); buffers[n] = b
        }
        let fmt = buffers["tap"]?.format ?? AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        for _ in 0..<12 {   // 同時発音数の上限
            let p = AVAudioPlayerNode(); engine.attach(p); engine.connect(p, to: sfxMix, format: fmt); voices.append(p)
        }
        for _ in 0..<3 {
            let p = AVAudioPlayerNode(); engine.attach(p); engine.connect(p, to: bgmMix, format: fmt); stems.append(p)
        }
        sfxMix.outputVolume = sfxVolume; bgmMix.outputVolume = bgmVolume
        start()
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in
            guard let t = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt, t == AVAudioSession.InterruptionType.ended.rawValue else { return }
            self?.start()
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.start() }
    }

    private func start() {
        if !engine.isRunning { try? engine.start() }
    }

    func play(_ name: String, volume: Float = 1, rate: Float = 1) {
        guard let b = buffers[name], engine.isRunning else { return }
        let now = CACurrentMediaTime()
        if let l = lastPlay[name], now - l < 0.03 { return }   // 同一音の連打抑制
        lastPlay[name] = now
        let v = voices[nextVoice]; nextVoice = (nextVoice + 1) % voices.count
        v.stop(); v.volume = volume
        v.scheduleBuffer(b, at: nil, options: .interrupts)
        v.play()
    }

    /// 連続ゲート通過で音程がペンタトニックに上昇
    func pop(scale: Int) {
        let i = min(comboStep, 7); comboStep += 1
        play("pop_\(popSet)_\(i)", volume: 0.8)
        if scale >= 2 { play(scale >= 3 ? "gate_big" : "gate_mul", volume: 0.7) }
    }

    func startBGM() {
        stop()
        guard engine.isRunning else { return }
        let names = ["bgm_micro_base", "bgm_micro_arp", "bgm_micro_drums"]
        let startTime = AVAudioTime(hostTime: mach_absolute_time() + 4_000_000)
        for (i, p) in stems.enumerated() {
            guard let b = buffers[names[i]] else { continue }
            p.volume = i == 0 ? 1 : 0
            p.scheduleBuffer(b, at: nil, options: .loops)
            p.play(at: startTime)
        }
        stemTarget = [1, 0, 0]
        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            for (i, p) in self.stems.enumerated() { p.volume += (self.stemTarget[i] - p.volume) * 0.06 }  // クロスフェード
        }
    }
    /// 0: 開始 1: 増殖中 2: 大量増殖/ボス
    func setIntensity(_ level: Int) {
        stemTarget = [1, level >= 1 ? 0.9 : 0, level >= 2 ? 1 : 0]
    }
    func duck(_ on: Bool) { stemTarget[0] = on ? 0.3 : 1 }
    func stop() { stems.forEach { $0.stop() } }
}

/// 音・映像・振動を同期させるための触覚
final class Haptics {
    static let shared = Haptics()
    private var engine: CHHapticEngine?
    var enabled = true
    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine(); engine?.isAutoShutdownEnabled = true
        try? engine?.start()
    }
    func tap(_ intensity: Float, sharp: Float = 0.6) {
        guard enabled else { return }
        play([CHHapticEvent(eventType: .hapticTransient, parameters: [.init(parameterID: .hapticIntensity, value: intensity), .init(parameterID: .hapticSharpness, value: sharp)], relativeTime: 0)])
    }
    func rumble(_ dur: Double, intensity: Float = 0.8) {
        guard enabled else { return }
        play([CHHapticEvent(eventType: .hapticContinuous, parameters: [.init(parameterID: .hapticIntensity, value: intensity), .init(parameterID: .hapticSharpness, value: 0.2)], relativeTime: 0, duration: dur)])
    }
    private func play(_ events: [CHHapticEvent]) {
        guard let engine, let p = try? CHHapticPattern(events: events, parameters: []) else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(); return
        }
        try? engine.start(); try? engine.makePlayer(with: p).start(atTime: 0)
    }
}
