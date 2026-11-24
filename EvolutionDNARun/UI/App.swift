import SwiftUI
import SceneKit

@main
struct EvolutionDNARunApp: App {
    var body: some Scene { WindowGroup { RootView().preferredColorScheme(.dark).statusBarHidden() } }
}

/// AI社員08: デザインシステム（オーナー提供のデザイン参考画像に準拠）
enum DS {
    static let navy = Color(red: 0.12, green: 0.18, blue: 0.42)
    static let good = Color(red: 0.30, green: 0.85, blue: 0.35)
    static let gold = Color(red: 1.0, green: 0.80, blue: 0.30)
    static let goldDeep = Color(red: 0.85, green: 0.55, blue: 0.1)
    static let violet = Color(red: 0.62, green: 0.40, blue: 1.0)
    static let blue = Color(red: 0.22, green: 0.50, blue: 0.98)
    static func font(_ s: CGFloat, _ w: Font.Weight = .heavy) -> Font { .system(size: s, weight: w, design: .rounded) }
}

struct RootView: View {
    enum Screen: Equatable { case home, game(Int), collection }
    @State private var screen: Screen = .home
    @State private var runID = 0   // 同じステージのリトライでもゲームを作り直す
    @ObservedObject var progress = Progress.shared
    var body: some View {
        ZStack {
            switch screen {
            case .home:
                HomeView(onPlay: { let d = UserDefaults.standard.integer(forKey: "debugStage"); screen = .game(d > 0 ? d : progress.data.currentStage) }, onCollection: { screen = .collection })
            case .game(let s):
                GameScreen(stageIndex: s, onExit: { next in runID += 1; screen = next.map { .game($0) } ?? .home }).id("\(s)-\(runID)")
            case .collection:
                CollectionView(onClose: { screen = .home })
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: screen)
    }
}

// MARK: - 共通部品
/// ゲーム風の立体ボタン（金縁・下に影）
struct GameButtonStyle: ButtonStyle {
    var top: Color; var bottom: Color; var radius: CGFloat = 40
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(LinearGradient(colors: [Color(red: 1, green: 0.95, blue: 0.6), DS.goldDeep], startPoint: .top, endPoint: .bottom), lineWidth: 5))
            .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 5)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct CircleIcon: View {
    let icon: String; var color: Color = DS.blue; let action: () -> Void
    var body: some View {
        Button(action: { AudioEngine.shared.play("tap"); action() }) {
            Image(systemName: icon).font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(LinearGradient(colors: [color.opacity(0.9), color], startPoint: .top, endPoint: .bottom), in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: 3)).shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 3)
        }
    }
}

struct GemCounter: View {
    let value: Int
    var body: some View {
        HStack(spacing: 6) {
            Text("💎").font(.system(size: 26)).padding(.leading, -6)
            Text(value.formatted()).font(DS.font(20)).foregroundStyle(.white).monospacedDigit()
        }
        .padding(.leading, 12).padding(.trailing, 14).padding(.vertical, 5)
        .background(DS.navy.opacity(0.85), in: Capsule())
    }
}

/// ステージ進行：丸ドット＋王冠
struct StageDots: View {
    let progress: Float
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<4) { i in
                let reached = progress >= Float(i) / 4
                Circle().fill(i == 0 ? DS.good : (reached ? DS.gold : Color(white: 0.3)))
                    .overlay(Circle().stroke(.white, lineWidth: 2)).frame(width: 20, height: 20)
                Rectangle().fill(progress >= Float(i + 1) / 4 ? DS.gold : Color(white: 0.35)).frame(height: 5)
            }
            Text("👑").font(.system(size: 22))
        }
        .frame(width: 190)
    }
}

struct Thumb: View {
    let e: Element; let k: Int; var size: CGFloat = 70; var locked = false
    var body: some View {
        Image(uiImage: Thumbnails.image(e, k)).resizable().scaledToFit().frame(width: size, height: size)
            .colorMultiply(locked ? .black : .white).opacity(locked ? 0.55 : 1)
            .overlay { if locked { Text("?").font(DS.font(size * 0.35, .black)).foregroundStyle(.white.opacity(0.8)) } }
    }
}

// MARK: - ホーム
struct HomeView: View {
    var onPlay: () -> Void
    var onCollection: () -> Void
    @ObservedObject var progress = Progress.shared
    @State private var showSettings = false
    @State private var pulse = false
    var body: some View {
        ZStack {
            // オーナー提供のホーム画面イラストをそのまま背景に使用
            GeometryReader { g in
                VStack(spacing: 0) {
                    Image(uiImage: Art.image("bg_home")).resizable().scaledToFill()
                        .frame(width: g.size.width, height: g.size.height * 0.72).clipped()
                    LinearGradient(colors: [Color(red: 0.55, green: 0.5, blue: 0.75), Color(red: 0.3, green: 0.25, blue: 0.5)], startPoint: .top, endPoint: .bottom)
                }
            }.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Thumb(e: .fire, k: 0, size: 54).scaleEffect(1.15)
                        .background(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.6), Color(red: 1, green: 0.6, blue: 0.35)], startPoint: .top, endPoint: .bottom), in: Circle())
                        .clipShape(Circle()).overlay(Circle().stroke(DS.gold, lineWidth: 4))
                    Spacer()
                    GemCounter(value: progress.data.dna)
                    CircleIcon(icon: "gearshape.fill") { showSettings = true }
                }.padding(.horizontal, 16).padding(.top, 6)
                VStack(spacing: -8) {
                    Text("Evolution").font(DS.font(42, .black)).foregroundStyle(.white)
                    Text("DNA Run").font(DS.font(46, .black))
                        .foregroundStyle(LinearGradient(colors: [Color(red: 0.6, green: 0.95, blue: 1), Color(red: 0.4, green: 0.6, blue: 1)], startPoint: .top, endPoint: .bottom))
                }
                .shadow(color: DS.navy, radius: 0, x: 0, y: 4).shadow(color: DS.navy, radius: 0, x: 2, y: 0).shadow(color: DS.navy, radius: 0, x: -2, y: 0)
                .padding(.top, 8)
                Spacer()
                Button(action: { AudioEngine.shared.play("tap"); onPlay() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.fill").font(.system(size: 44, weight: .black))
                        VStack(alignment: .leading, spacing: -2) {
                            Text("PLAY").font(DS.font(30, .black))
                            Text("STAGE \(progress.data.currentStage)").font(DS.font(14, .bold)).opacity(0.9)
                        }
                    }
                    .foregroundStyle(.white).shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 2)
                    .frame(width: 270, height: 92)
                }
                .buttonStyle(GameButtonStyle(top: Color(red: 0.55, green: 0.98, blue: 0.3), bottom: Color(red: 0.15, green: 0.72, blue: 0.15), radius: 46))
                .scaleEffect(pulse ? 1.03 : 1)
                Button(action: { AudioEngine.shared.play("tap"); onCollection() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "book.fill").font(.system(size: 26, weight: .bold))
                        Text("図鑑").font(DS.font(20))
                    }.foregroundStyle(.white).frame(width: 150, height: 64)
                }
                .buttonStyle(GameButtonStyle(top: Color(red: 1, green: 0.85, blue: 0.3), bottom: Color(red: 0.95, green: 0.6, blue: 0.1), radius: 32))
                .padding(.top, 18).padding(.bottom, 36)
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever()) { pulse = true } }
        .sheet(isPresented: $showSettings) { SettingsView().presentationDetents([.large]) }
    }
}

/// ホームの3Dステージ：楽園の背景、石の台座、光るリング、DNAらせん、クリスタル、翼のある子ドラゴン
struct ShowcaseView: UIViewRepresentable {
    func makeUIView(context: Context) -> SCNView {
        let v = SCNView(); v.antialiasingMode = .multisampling4X
        let s = SCNScene(); v.scene = s; v.isPlaying = true; v.rendersContinuously = true
        s.background.contents = FX.gradientImage(UIColor(red: 0.22, green: 0.55, blue: 0.98, alpha: 1), UIColor(red: 0.8, green: 0.93, blue: 1, alpha: 1))
        let cam = SCNNode(); cam.camera = SCNCamera(); cam.camera!.fieldOfView = 50
        cam.camera!.wantsHDR = true; cam.camera!.wantsExposureAdaptation = false; cam.camera!.exposureOffset = 0.15
        cam.camera!.bloomIntensity = 0.5; cam.camera!.bloomThreshold = 0.9; cam.camera!.saturation = 1.2
        cam.position = SCNVector3(0, 2.4, 11.5); cam.look(at: SCNVector3(0, 1.6, 0)); s.rootNode.addChildNode(cam); v.pointOfView = cam
        let sun = SCNNode(); sun.light = SCNLight(); sun.light!.type = .directional; sun.light!.intensity = 1100; sun.eulerAngles = SCNVector3(-0.8, 0.5, 0); s.rootNode.addChildNode(sun)
        let amb = SCNNode(); amb.light = SCNLight(); amb.light!.type = .ambient; amb.light!.intensity = 650; s.rootNode.addChildNode(amb)
        var rng = SplitMix64(seed: 9)
        let water = SCNNode(geometry: SCNPlane(width: 160, height: 160)); water.eulerAngles.x = -.pi / 2; water.position = SCNVector3(0, -0.6, -30)
        let wm = SCNMaterial(); wm.lightingModel = .constant; wm.diffuse.contents = UIColor(red: 0.2, green: 0.72, blue: 0.98, alpha: 1); water.geometry!.materials = [wm]
        s.rootNode.addChildNode(water)
        for (x, y, z, big) in [(-9.0, 4.0, -18.0, true), (10.0, 6.0, -22.0, true), (-4.0, 9.0, -32.0, false), (6.0, 2.5, -12.0, false)] {
            let n = WorldJungle.floatingIsland(&rng, big: big); n.position = SCNVector3(Float(x), Float(y), Float(z)); s.rootNode.addChildNode(n)
        }
        for (x, z) in [(-4.2, -1.5), (4.4, -2.0), (-5.0, 2.0), (5.0, 2.5)] {
            let isle = WorldJungle.islet(&rng); isle.position = SCNVector3(Float(x), -0.5, Float(z)); s.rootNode.addChildNode(isle)
        }
        for i in 0..<4 { let c = WorldJungle.cloud(&rng); c.position = SCNVector3(Float(i % 2 == 0 ? -1 : 1) * Float(8 + i * 4), Float(11 + i), -38); s.rootNode.addChildNode(c) }
        let stone = SCNNode(geometry: SCNCylinder(radius: 1.7, height: 0.5)); stone.geometry!.materials = [Toon.mat(UIColor(red: 0.72, green: 0.72, blue: 0.8, alpha: 1), rimStrength: 0.3)]
        stone.position = SCNVector3(0, -0.25, 0); s.rootNode.addChildNode(stone)
        let ring = SCNNode(geometry: SCNTorus(ringRadius: 1.55, pipeRadius: 0.05)); ring.geometry!.materials = [Mat.glow(UIColor(red: 0.4, green: 0.9, blue: 1, alpha: 1))]
        ring.position.y = 0.02; s.rootNode.addChildNode(ring)
        ring.runAction(.repeatForever(.sequence([.fadeOpacity(to: 0.5, duration: 0.8), .fadeOpacity(to: 1, duration: 0.8)])))
        let helix = Helix.node(); helix.scale = SCNVector3(2.2, 2.2, 2.2); helix.position = SCNVector3(0, 2.6, -4.5); s.rootNode.addChildNode(helix)
        helix.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 6)))
        for (x, h) in [(-2.3, 1.3), (2.4, 1.0)] {
            let c = WorldJungle.crystal(UIColor(red: 0.8, green: 0.55, blue: 1, alpha: 1), h: Float(h)); c.position = SCNVector3(Float(x), 0.5, 0.6); s.rootNode.addChildNode(c)
        }
        let d = CreatureFactory.build(element: .fire, sizeClass: 1)
        d.scale = SCNVector3(1.9, 1.9, 1.9); d.eulerAngles.y = .pi; d.position.y = 0.05
        s.rootNode.addChildNode(d)
        d.childNode(withName: "body", recursively: false)?.runAction(.repeatForever(.sequence([.scale(to: 1.04, duration: 1.0), .scale(to: 0.98, duration: 1.0)])))
        d.runAction(.repeatForever(.sequence([.rotateTo(x: 0, y: .pi + 0.35, z: 0, duration: 2.5), .rotateTo(x: 0, y: .pi - 0.35, z: 0, duration: 2.5)])))
        let sp = SCNParticleSystem(); sp.particleImage = FX.softDot; sp.birthRate = 20; sp.particleLifeSpan = 1.5; sp.particleSize = 0.12
        sp.particleColor = UIColor(red: 1, green: 0.9, blue: 0.6, alpha: 1); sp.blendMode = .additive; sp.emitterShape = SCNSphere(radius: 1.6); sp.particleVelocity = 0.3
        let spn = SCNNode(); spn.position = SCNVector3(0, 1.3, 0); spn.addParticleSystem(sp); s.rootNode.addChildNode(spn)
        return v
    }
    func updateUIView(_ uiView: SCNView, context: Context) {}
}

struct SettingsView: View {
    @ObservedObject var p = Progress.shared
    @Environment(\.dismiss) private var dismiss
    @State private var bgm: Float = Progress.shared.data.bgmVolume
    @State private var sfx: Float = Progress.shared.data.sfxVolume
    @State private var haptics = Progress.shared.data.haptics
    @AppStorage(GameSettings.Key.muteAll) private var muteAll = false
    @AppStorage(GameSettings.Key.hapticStrength) private var hapticStrength = 1.0
    @AppStorage(GameSettings.Key.sensitivity) private var sensitivity = 1.0
    @AppStorage(GameSettings.Key.quality) private var quality = 1
    @AppStorage(GameSettings.Key.batterySaver) private var batterySaver = false
    @AppStorage(GameSettings.Key.screenShake) private var screenShake = true
    @AppStorage(GameSettings.Key.reduceFlash) private var reduceFlash = false
    @AppStorage(GameSettings.Key.shortNumbers) private var shortNumbers = true
    @AppStorage(GameSettings.Key.showTutorialHint) private var showHint = true
    @State private var confirmReset = false
    @State private var info: String?
    private var version: String { (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-") + " (" + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-") + ")" }

    var body: some View {
        NavigationStack {
            Form {
                Section("サウンド") {
                    Toggle("すべての音をミュート", isOn: $muteAll)
                    HStack { Label("BGM", systemImage: "music.note"); Slider(value: $bgm, in: 0...1) }.disabled(muteAll)
                    HStack { Label("効果音", systemImage: "speaker.wave.2.fill"); Slider(value: $sfx, in: 0...1) }.disabled(muteAll)
                    Button("効果音をテスト") { AudioEngine.shared.play("gate_big") }.disabled(muteAll)
                }
                Section("振動") {
                    Toggle("振動（ハプティクス）", isOn: $haptics)
                    Picker("強さ", selection: $hapticStrength) { Text("弱").tag(0.5); Text("中").tag(1.0); Text("強").tag(1.5) }
                        .pickerStyle(.segmented).disabled(!haptics)
                }
                Section {
                    HStack { Text("操作感度"); Slider(value: $sensitivity, in: 0.5...2.0, step: 0.1); Text(String(format: "%.1f", sensitivity)).monospacedDigit().frame(width: 34) }
                    Toggle("スタート時の操作ガイドを表示", isOn: $showHint)
                } header: { Text("操作") } footer: { Text("感度を上げると、少しのスワイプで大きく動きます。") }
                Section {
                    Picker("画質", selection: $quality) { Text("省電力").tag(0); Text("標準").tag(1); Text("高画質").tag(2) }
                        .pickerStyle(.segmented).disabled(batterySaver)
                    Toggle("バッテリー節約モード", isOn: $batterySaver)
                    Toggle("画面の揺れ", isOn: $screenShake)
                    Toggle("強い光の点滅をおさえる", isOn: $reduceFlash)
                    Toggle("大きな数を短く表示（1.2K）", isOn: $shortNumbers)
                } header: { Text("画面・グラフィック") } footer: { Text("画質の変更は次のステージから反映されます。高画質は120fps対応端末でなめらかになります。") }
                Section("データ") {
                    LabeledContent("進行状況", value: "ステージ \(p.data.currentStage)")
                    LabeledContent("所持DNA", value: "\(p.data.dna)")
                    Button("購入を復元") { info = "アプリ内課金は準備中です。" }
                    Button("進行状況をリセット", role: .destructive) { confirmReset = true }
                }
                Section("サポート") {
                    Button("遊び方") { info = "左右にスワイプしてゲートを選び、仲間を増やしましょう。\nボスの弱点の属性に進化すると2倍のダメージ！\n10体以上で「融合」ゲートを通ると強い個体に。" }
                    Button("プライバシーポリシー") { info = "公開前に掲載予定です。" }
                    Button("利用規約") { info = "公開前に掲載予定です。" }
                    Button("クレジット") { info = "Evolution DNA Run\n企画・開発・音楽: AI開発チーム\nイラスト: オーナー提供" }
                    LabeledContent("バージョン", value: version)
                }
            }
            .navigationTitle("設定").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } } }
        }
        .onChange(of: bgm) { _, _ in commit() }.onChange(of: sfx) { _, _ in commit() }.onChange(of: haptics) { _, _ in commit() }
        .onChange(of: muteAll) { _, v in AudioEngine.shared.muted = v }
        .onChange(of: hapticStrength) { _, _ in Haptics.shared.tap(0.8) }
        .confirmationDialog("進行状況をリセットしますか？", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("リセットする", role: .destructive) { p.resetAll() }
        } message: { Text("クリアしたステージ・DNA・図鑑がすべて消えます。元に戻せません。") }
        .alert("お知らせ", isPresented: Binding(get: { info != nil }, set: { if !$0 { info = nil } })) { Button("OK") {} } message: { Text(info ?? "") }
    }
    private func commit() { p.setVolumes(bgm: bgm, sfx: sfx, haptics: haptics) }
}

// MARK: - 図鑑（属性ごとの進化ライン、未発見はシルエット）
struct CollectionView: View {
    var onClose: () -> Void
    @ObservedObject var progress = Progress.shared
    let lines: [Element] = [.fire, .ice, .thunder, .none]
    var discoveredCount: Int { lines.flatMap { e in (0..<4).map { "\(e.rawValue)-\($0)" } }.filter { progress.data.discovered.contains($0) }.count }
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.25, green: 0.2, blue: 0.55), Color(red: 0.1, green: 0.12, blue: 0.3)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    CircleIcon(icon: "chevron.left", action: onClose)
                    Spacer()
                    VStack(spacing: 0) {
                        Text("生物図鑑").font(DS.font(26, .black)).foregroundStyle(.white)
                        Text("\(discoveredCount) / \(lines.count * 4) 発見").font(DS.font(13, .bold)).foregroundStyle(DS.gold)
                    }
                    Spacer()
                    Color.clear.frame(width: 50, height: 50)
                }.padding(.horizontal, 16)
                ScrollView {
                    VStack(spacing: 12) { ForEach(lines, id: \.self) { e in row(e) } }.padding(12)
                }
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 26))
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(LinearGradient(colors: [DS.gold, DS.goldDeep], startPoint: .top, endPoint: .bottom), lineWidth: 4))
                .padding(.horizontal, 10)
            }
        }
    }
    func row(_ e: Element) -> some View {
        let c = Color(Palette.color(e))
        return HStack(spacing: 2) {
            Text(e == .none ? "🦠" : (e == .fire ? "🔥" : e == .ice ? "❄️" : "⚡️")).font(.system(size: 20))
                .frame(width: 38, height: 38).background(c, in: Circle()).overlay(Circle().stroke(DS.gold, lineWidth: 3))
            ForEach(0..<4) { k in
                let found = progress.data.discovered.contains("\(e.rawValue)-\(k)")
                VStack(spacing: 0) {
                    Thumb(e: e, k: k, size: 64, locked: !found)
                    HStack(spacing: 0) { ForEach(0..<(k + 1), id: \.self) { _ in Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(DS.gold) } }
                    Text(found ? CreatureCatalog.name(element: e, sizeClass: k) : "???").font(DS.font(8, .bold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                }.frame(maxWidth: .infinity)
                if k < 3 { Image(systemName: "arrowtriangle.right.fill").font(.system(size: 9)).foregroundStyle(.white.opacity(0.7)) }
            }
        }
        .padding(8)
        .background(LinearGradient(colors: [c.opacity(0.55), c.opacity(0.2)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.5), lineWidth: 2))
    }
}

// MARK: - ゲーム画面
struct GameScreen: View {
    @StateObject private var game: GameController
    @ObservedObject var progress = Progress.shared
    var onExit: (Int?) -> Void
    init(stageIndex: Int, onExit: @escaping (Int?) -> Void) {
        _game = StateObject(wrappedValue: GameController(stageIndex: stageIndex)); self.onExit = onExit
    }
    var body: some View {
        ZStack {
            SceneHost(view: game.view).ignoresSafeArea()
            VStack(spacing: 8) {
                HStack(alignment: .top) {
                    CircleIcon(icon: "house.fill") { game.stop(); onExit(nil) }
                    Spacer()
                    VStack(spacing: 4) {
                        Text("STAGE \(game.stage.index)").font(DS.font(18, .black)).foregroundStyle(.white)
                            .padding(.horizontal, 18).padding(.vertical, 3).background(DS.navy.opacity(0.85), in: Capsule())
                        StageDots(progress: game.progress)
                    }
                    Spacer()
                    GemCounter(value: progress.data.dna + game.dnaCollected).scaleEffect(0.85)
                }.padding(.horizontal, 12).padding(.top, 4)
                HStack(alignment: .top) {
                    EvolutionPanel(element: game.element, sizeClass: game.sizeClass)
                    Spacer()
                    if game.phase == .boss || game.phase == .won {
                        VStack(spacing: 4) {
                            Text("\(game.stage.boss.name)  弱点 \(game.stage.boss.weakness.symbol)").font(DS.font(14)).foregroundStyle(.white)
                            ProgressBar(value: Float(game.bossHP), color: Color(red: 1, green: 0.3, blue: 0.45)).frame(width: 180)
                        }.padding(10).background(DS.navy.opacity(0.8), in: RoundedRectangle(cornerRadius: 16)).transition(.scale)
                    }
                }.padding(.horizontal, 12)
                Spacer()
            }
            VStack {
                Spacer()
                ZStack {
                    ForEach(game.popups) { p in
                        Text(p.text).font(DS.font(46, .black)).foregroundStyle(p.color)
                            .shadow(color: .black.opacity(0.45), radius: 0, x: 0, y: 3)
                            .transition(.asymmetric(insertion: .scale(scale: 0.3).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
                    }
                }.animation(.spring(response: 0.3, dampingFraction: 0.55), value: game.popups.map(\.id))
                if let n = game.evolvedName {
                    VStack(spacing: 0) {
                        Thumb(e: game.element, k: game.sizeClass, size: 80)
                        Text("EVOLUTION!").font(DS.font(20, .black)).foregroundStyle(DS.gold)
                        Text(n).font(DS.font(24, .black)).foregroundStyle(.white)
                    }.padding(.horizontal, 20).padding(.vertical, 8)
                    .background(LinearGradient(colors: [DS.violet, DS.navy], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 26))
                    .overlay(RoundedRectangle(cornerRadius: 26).stroke(DS.gold, lineWidth: 4))
                    .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                if game.phase == .ready && (GameSettings.showHint || game.stage.index <= 3) {
                    VStack(spacing: 8) {
                        Image(systemName: "hand.draw.fill").font(.system(size: 44)).foregroundStyle(.white)
                        Text("左右にスワイプしてスタート").font(DS.font(20)).foregroundStyle(.white)
                    }.shadow(color: .black.opacity(0.4), radius: 3).padding(.bottom, 90)
                }
                HStack {
                    Spacer()
                    Button { game.useAbility() } label: {
                        ZStack {
                            Circle().fill(RadialGradient(colors: [Color(red: 0.55, green: 0.35, blue: 0.95), Color(red: 0.2, green: 0.1, blue: 0.45)], center: .center, startRadius: 4, endRadius: 60))
                            Text("🧬").font(.system(size: 50)).rotationEffect(.degrees(-20))
                        }
                        .frame(width: 104, height: 104)
                        .overlay(Circle().stroke(LinearGradient(colors: [Color(red: 1, green: 0.95, blue: 0.6), DS.goldDeep], startPoint: .top, endPoint: .bottom), lineWidth: 7))
                        .shadow(color: DS.gold.opacity(game.abilityReady ? 0.9 : 0), radius: 14)
                        .opacity(game.abilityReady ? 1 : 0.6)
                    }
                    .disabled(!game.abilityReady)
                    .padding(.trailing, 20).padding(.bottom, 30)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: game.evolvedName)
            if game.phase == .won || game.phase == .lost { ResultCard(game: game, onExit: onExit).transition(.scale.combined(with: .opacity)) }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { v in game.drag(dx: v.translation.width, width: UIScreen.main.bounds.width) }.onEnded { _ in game.endDrag() })
        .animation(.spring(response: 0.45, dampingFraction: 0.75).delay(game.phase == .won ? 2.3 : 0.3), value: game.phase)
        .onDisappear { game.stop() }
    }
}

/// 画面左の進化段階パネル（現在の系統の 3 段階）
struct EvolutionPanel: View {
    let element: Element; let sizeClass: Int
    var body: some View {
        let e = element == .none ? Element.fire : element
        VStack(spacing: 2) {
            ForEach(0..<3) { k in
                let current = element != .none && k == min(sizeClass, 2)
                let unlocked = element != .none && k <= sizeClass
                Thumb(e: e, k: k, size: 54, locked: !unlocked)
                    .frame(width: 62, height: 62)
                    .background(Circle().fill(LinearGradient(colors: [Color(red: 0.85, green: 0.95, blue: 1), Color(red: 0.5, green: 0.75, blue: 1)], startPoint: .top, endPoint: .bottom)))
                    .overlay(Circle().stroke(current ? DS.gold : .white.opacity(0.7), lineWidth: current ? 4 : 2))
                    .shadow(color: current ? DS.gold : .clear, radius: 8)
                if k < 2 { Image(systemName: "arrowtriangle.down.fill").font(.system(size: 10)).foregroundStyle(.white) }
            }
        }
        .padding(6)
        .background(DS.navy.opacity(0.85), in: Capsule())
        .overlay(Capsule().stroke(Color(red: 0.4, green: 0.7, blue: 1), lineWidth: 2))
    }
}

struct ResultCard: View {
    @ObservedObject var game: GameController
    var onExit: (Int?) -> Void
    var body: some View {
        let won = game.phase == .won
        VStack(spacing: 14) {
            if won {
                VStack(spacing: -10) {
                    Text("👑").font(.system(size: 56))
                    Text("BOSS CLEAR!").font(DS.font(42, .black)).italic()
                        .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.95, blue: 0.6), DS.goldDeep], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Color(red: 0.4, green: 0.15, blue: 0.05), radius: 0, x: 0, y: 4)
                }
                HStack(spacing: 6) { ForEach(0..<3) { _ in Image(systemName: "star.fill").font(.system(size: 40)).foregroundStyle(DS.gold).shadow(color: .orange, radius: 6) } }
                HStack { Text("💎"); Text("+\(20 + game.stage.index * 5 + game.dnaCollected)").font(DS.font(26)).foregroundStyle(.white) }
                if game.element != .none { Thumb(e: game.element, k: game.sizeClass, size: 100) }
            } else {
                Text("GAME OVER").font(DS.font(38, .black)).foregroundStyle(.white)
                Text(String(localized: "ボスの弱点属性で進化するか、\n融合で強い個体を作ろう")).font(DS.font(16, .bold)).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.9))
            }
            Button { onExit(won ? game.stage.index + 1 : game.stage.index) } label: {
                Text(won ? "NEXT" : "RETRY").font(DS.font(28, .black)).foregroundStyle(.white).frame(width: 210, height: 66)
            }.buttonStyle(GameButtonStyle(top: Color(red: 0.55, green: 0.98, blue: 0.3), bottom: Color(red: 0.15, green: 0.72, blue: 0.15), radius: 33))
            Button("ホーム") { onExit(nil) }.font(DS.font(16, .bold)).foregroundStyle(.white.opacity(0.85))
        }
        .padding(26)
        .background(LinearGradient(colors: [Color(red: 0.35, green: 0.2, blue: 0.7).opacity(0.96), DS.navy.opacity(0.96)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 32))
        .overlay(RoundedRectangle(cornerRadius: 32).stroke(LinearGradient(colors: [DS.gold, DS.goldDeep], startPoint: .top, endPoint: .bottom), lineWidth: 4))
        .padding(28)
    }
}

struct SceneHost: UIViewRepresentable {
    let view: SCNView
    func makeUIView(context: Context) -> SCNView { view }
    func updateUIView(_ uiView: SCNView, context: Context) {}
}

struct ProgressBar: View {
    var value: Float; var color: Color
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25))
                Capsule().fill(color).frame(width: max(8, g.size.width * CGFloat(value)))
            }
        }.frame(height: 10)
    }
}
