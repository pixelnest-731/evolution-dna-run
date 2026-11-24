import SwiftUI
import SceneKit

@main
struct EvolutionDNARunApp: App {
    var body: some Scene { WindowGroup { RootView().preferredColorScheme(.dark).statusBarHidden() } }
}

enum DS {   // AI社員08: デザインシステム（C案：プレミアム3Dハイブリッド／明るいトゥーン）
    static let sky = Color(red: 0.36, green: 0.72, blue: 1.0)
    static let navy = Color(red: 0.10, green: 0.16, blue: 0.42)
    static let good = Color(red: 0.30, green: 0.85, blue: 0.40)
    static let gold = Color(red: 1.0, green: 0.78, blue: 0.25)
    static let violet = Color(red: 0.62, green: 0.40, blue: 1.0)
    static func font(_ s: CGFloat, _ w: Font.Weight = .heavy) -> Font { .system(size: s, weight: w, design: .rounded) }
}

struct RootView: View {
    @State private var stageIndex: Int?
    @ObservedObject var progress = Progress.shared
    var body: some View {
        ZStack {
            if let s = stageIndex {
                GameScreen(stageIndex: s, onExit: { next in stageIndex = next })
                    .id(s).transition(.opacity)
            } else {
                HomeView(onPlay: { stageIndex = progress.data.currentStage })
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: stageIndex)
    }
}

// MARK: - ホーム
struct HomeView: View {
    var onPlay: () -> Void
    @ObservedObject var progress = Progress.shared
    @State private var showSettings = false
    @State private var pulse = false
    var body: some View {
        ZStack {
            LinearGradient(colors: [DS.sky, Color(red: 0.55, green: 0.85, blue: 1), Color(red: 0.6, green: 0.95, blue: 0.85)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ShowcaseView().ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    CircleButton(icon: "gearshape.fill") { showSettings = true }
                    Spacer()
                    Pill { Image(systemName: "diamond.fill").foregroundStyle(DS.violet); Text("\(progress.data.dna) DNA").font(DS.font(18)) }
                }.padding(.horizontal, 18).padding(.top, 8)
                VStack(spacing: -6) {
                    Text("Evolution").font(DS.font(46, .black))
                    Text("DNA Run").font(DS.font(52, .black)).foregroundStyle(LinearGradient(colors: [DS.gold, Color(red: 1, green: 0.5, blue: 0.3)], startPoint: .top, endPoint: .bottom))
                }
                .foregroundStyle(.white).shadow(color: DS.navy.opacity(0.6), radius: 0, x: 0, y: 4).padding(.top, 18)
                Text("1匹から、最強の生命体へ。").font(DS.font(16, .bold)).foregroundStyle(.white).shadow(color: DS.navy.opacity(0.5), radius: 2).padding(.top, 6)
                Spacer()
                Button(action: { AudioEngine.shared.play("tap"); onPlay() }) {
                    VStack(spacing: 2) {
                        Text("PLAY").font(DS.font(38, .black))
                        Text("STAGE \(progress.data.currentStage)").font(DS.font(15, .bold)).opacity(0.85)
                    }
                    .foregroundStyle(.white).frame(width: 250, height: 92)
                    .background(LinearGradient(colors: [Color(red: 0.45, green: 0.95, blue: 0.45), Color(red: 0.15, green: 0.7, blue: 0.3)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 30))
                    .overlay(RoundedRectangle(cornerRadius: 30).stroke(.white.opacity(0.8), lineWidth: 3))
                    .shadow(color: Color(red: 0.05, green: 0.4, blue: 0.15), radius: 0, x: 0, y: 6)
                    .scaleEffect(pulse ? 1.04 : 1)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever()) { pulse = true } }
        .sheet(isPresented: $showSettings) { SettingsView().presentationDetents([.medium]) }
    }
}

/// ホームのお気に入り生命体（呼吸・瞬き・ゆっくり回転）
struct ShowcaseView: UIViewRepresentable {
    func makeUIView(context: Context) -> SCNView {
        let v = SCNView(); v.backgroundColor = .clear; v.antialiasingMode = .multisampling4X
        let s = SCNScene(); v.scene = s; v.isPlaying = true; v.allowsCameraControl = false
        let cam = SCNNode(); cam.camera = SCNCamera(); cam.camera!.fieldOfView = 35; cam.position = SCNVector3(0, 1.2, 7.5); cam.look(at: SCNVector3(0, 0.3, 0))
        s.rootNode.addChildNode(cam)
        let l = SCNNode(); l.light = SCNLight(); l.light!.type = .directional; l.light!.intensity = 1000; l.eulerAngles = SCNVector3(-0.8, 0.5, 0); s.rootNode.addChildNode(l)
        let a = SCNNode(); a.light = SCNLight(); a.light!.type = .ambient; a.light!.intensity = 500; s.rootNode.addChildNode(a)
        let pedestal = SCNNode(geometry: SCNCylinder(radius: 0.9, height: 0.2))
        pedestal.geometry!.materials = [Mat.jelly(UIColor(red: 0.6, green: 0.9, blue: 1, alpha: 1), alpha: 0.7)]
        pedestal.position = SCNVector3(0, -0.85, 0); pedestal.scale = SCNVector3(1, 1, 1); s.rootNode.addChildNode(pedestal)
        let c = CreatureFactory.unit(element: .fire, sizeClass: 0); c.scale = SCNVector3(1.5, 1.5, 1.5); c.position.y = -0.25
        s.rootNode.addChildNode(c)
        c.runAction(.repeatForever(.sequence([.rotateTo(x: 0, y: 0.5, z: 0, duration: 2.5), .rotateTo(x: 0, y: -0.5, z: 0, duration: 2.5)])))
        return v
    }
    func updateUIView(_ uiView: SCNView, context: Context) {}
}

struct SettingsView: View {
    @ObservedObject var p = Progress.shared
    @State private var bgm: Float = Progress.shared.data.bgmVolume
    @State private var sfx: Float = Progress.shared.data.sfxVolume
    @State private var haptics = Progress.shared.data.haptics
    var body: some View {
        Form {
            Section("サウンド") {
                HStack { Text("BGM"); Slider(value: $bgm, in: 0...1) }
                HStack { Text("効果音"); Slider(value: $sfx, in: 0...1) }
                Toggle("振動", isOn: $haptics)
            }
        }
        .onChange(of: bgm) { _, _ in commit() }.onChange(of: sfx) { _, _ in commit() }.onChange(of: haptics) { _, _ in commit() }
    }
    private func commit() { p.setVolumes(bgm: bgm, sfx: sfx, haptics: haptics) }
}

// MARK: - ゲーム画面
struct GameScreen: View {
    @StateObject private var game: GameController
    var onExit: (Int?) -> Void
    init(stageIndex: Int, onExit: @escaping (Int?) -> Void) {
        _game = StateObject(wrappedValue: GameController(stageIndex: stageIndex)); self.onExit = onExit
    }
    var body: some View {
        ZStack {
            SceneHost(view: game.view).ignoresSafeArea()
            VStack {
                HStack(spacing: 10) {
                    CircleButton(icon: "house.fill") { game.stop(); onExit(nil) }
                    VStack(spacing: 4) {
                        Text("STAGE \(game.stage.index)").font(DS.font(16)).foregroundStyle(.white)
                        ProgressBar(value: game.progress, color: DS.good)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 6).background(DS.navy.opacity(0.75), in: Capsule())
                    Spacer()
                }.padding(.horizontal, 16).padding(.top, 6)
                if game.phase == .boss || game.phase == .won {
                    VStack(spacing: 4) {
                        Text("\(game.stage.boss.name)  弱点 \(game.stage.boss.weakness.symbol)").font(DS.font(15)).foregroundStyle(.white)
                        ProgressBar(value: Float(game.bossHP), color: Color(red: 1, green: 0.3, blue: 0.45)).frame(width: 240)
                    }.padding(10).background(DS.navy.opacity(0.75), in: RoundedRectangle(cornerRadius: 16)).transition(.scale)
                }
                Spacer()
                ZStack {
                    ForEach(game.popups) { p in
                        Text(p.text).font(DS.font(44, .black)).foregroundStyle(p.color)
                            .shadow(color: .black.opacity(0.5), radius: 0, x: 0, y: 3).transition(.asymmetric(insertion: .scale(scale: 0.3).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
                    }
                }.animation(.spring(response: 0.3, dampingFraction: 0.55), value: game.popups.map(\.id))
                if let n = game.evolvedName {
                    VStack(spacing: 0) {
                        Text("EVOLUTION!").font(DS.font(20, .black)).foregroundStyle(DS.gold)
                        Text(n).font(DS.font(34, .black)).foregroundStyle(.white)
                    }.padding(.horizontal, 24).padding(.vertical, 10)
                    .background(LinearGradient(colors: [DS.violet, DS.navy], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 22))
                    .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                if game.phase == .ready {
                    VStack(spacing: 8) {
                        Image(systemName: "hand.draw.fill").font(.system(size: 44)).foregroundStyle(.white)
                        Text("左右にスワイプしてスタート").font(DS.font(20)).foregroundStyle(.white)
                    }.shadow(radius: 4).padding(.bottom, 80)
                }
                if game.abilityReady {
                    Button { game.useAbility() } label: {
                        VStack { Image(systemName: "sparkles").font(.system(size: 34, weight: .bold)); Text("DNA BURST").font(DS.font(13)) }
                            .foregroundStyle(.white).frame(width: 110, height: 110)
                            .background(RadialGradient(colors: [DS.violet, DS.navy], center: .center, startRadius: 5, endRadius: 60), in: Circle())
                            .overlay(Circle().stroke(DS.gold, lineWidth: 5))
                    }.padding(.bottom, 40).transition(.scale)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: game.phase)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: game.evolvedName)
            if game.phase == .won || game.phase == .lost { ResultCard(game: game, onExit: onExit).transition(.scale.combined(with: .opacity)) }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { v in game.drag(dx: v.translation.width, width: UIScreen.main.bounds.width) }.onEnded { _ in game.endDrag() })
        .animation(.spring(response: 0.45, dampingFraction: 0.75).delay(game.phase == .won ? 1.2 : 0.3), value: game.phase)
        .onDisappear { game.stop() }
    }
}

struct ResultCard: View {
    @ObservedObject var game: GameController
    var onExit: (Int?) -> Void
    var body: some View {
        let won = game.phase == .won
        VStack(spacing: 14) {
            Text(won ? "STAGE CLEAR!" : "GAME OVER").font(DS.font(36, .black)).foregroundStyle(won ? DS.gold : .white)
            if won {
                HStack(spacing: 6) { ForEach(0..<3) { _ in Image(systemName: "star.fill").font(.system(size: 40)).foregroundStyle(DS.gold) } }
                Text("+\(20 + game.stage.index * 5) DNA").font(DS.font(24)).foregroundStyle(.white)
            } else {
                Text(String(localized: "ボスの弱点属性で進化するか、\n融合で強い個体を作ろう")).font(DS.font(16, .bold)).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.9))
            }
            Button { onExit(won ? game.stage.index + 1 : game.stage.index) } label: {
                Text(won ? "NEXT" : "RETRY").font(DS.font(26, .black)).foregroundStyle(.white).frame(width: 200, height: 64)
                    .background(DS.good, in: RoundedRectangle(cornerRadius: 22))
            }
            Button("ホーム") { onExit(nil) }.font(DS.font(16, .bold)).foregroundStyle(.white.opacity(0.85))
        }
        .padding(28)
        .background(LinearGradient(colors: [DS.navy.opacity(0.95), Color(red: 0.2, green: 0.15, blue: 0.5).opacity(0.95)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 32))
        .overlay(RoundedRectangle(cornerRadius: 32).stroke(.white.opacity(0.3), lineWidth: 2))
        .padding(30)
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
        }.frame(height: 10).frame(minWidth: 160)
    }
}

struct CircleButton: View {
    let icon: String; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                .frame(width: 50, height: 50).background(Color(red: 0.2, green: 0.45, blue: 0.95), in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: 3))
        }
    }
}

struct Pill<C: View>: View {
    @ViewBuilder var content: C
    var body: some View {
        HStack(spacing: 6) { content }.foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 8).background(DS.navy.opacity(0.8), in: Capsule())
    }
}
