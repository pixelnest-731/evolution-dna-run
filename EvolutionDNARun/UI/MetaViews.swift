import SwiftUI
import UIKit

// MARK: - 広告（AdMob 差し替え前提のテスト実装）
/// 本番では Google Mobile Ads SDK の RewardedAd / InterstitialAd に差し替える（docs/ADS.md）。
/// 本番広告IDの設定はオーナー承認後。現状は「テスト広告」画面を数秒表示する。
@MainActor
final class AdService: ObservableObject {
    static let shared = AdService()
    /// 広告を出せる状態か。AdMob SDK 接続前のリリースビルドでは false にして、
    /// 「テスト表示」の仮広告や広告ボタンが審査・本番で出ないようにする（審査ガイドライン 2.1）。
    #if DEBUG
    static let available = true
    #else
    static let available = false   // AdMob 接続後に true へ（オーナー承認事項）
    #endif
    struct Request: Identifiable { let id = UUID(); let rewarded: Bool; let placement: String; let done: (Bool) -> Void }
    @Published var current: Request? { didSet { present() } }
    private var window: UIWindow?
    /// シートより前面に出すため専用ウィンドウで表示
    private func present() {
        window?.isHidden = true; window = nil   // 前の広告ウィンドウが残って操作をふさがないように
        if let req = current {
            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { current = nil; req.done(!req.rewarded); return }
            let w = UIWindow(windowScene: scene); w.windowLevel = .alert + 1
            let vc = UIHostingController(rootView: AdOverlay(req: req)); vc.view.backgroundColor = .clear
            w.rootViewController = vc; w.makeKeyAndVisible(); window = w
        } else { window?.isHidden = true; window = nil }
    }
    /// 報酬型広告：最後まで見たら true
    func showRewarded(_ placement: String, done: @escaping (Bool) -> Void) {
        guard AdService.available else { done(false); return }
        AudioEngine.shared.duck(true)
        current = Request(rewarded: true, placement: placement) { ok in AudioEngine.shared.duck(false); if ok { Meta.shared.noteRewardedWatched() }; done(ok) }
    }
    func showInterstitial(_ placement: String, done: @escaping () -> Void) {
        guard AdService.available else { done(); return }
        current = Request(rewarded: false, placement: placement) { _ in done() }
    }
}

struct AdOverlay: View {
    let req: AdService.Request
    @State private var left = 5
    @State private var timer: Timer?
    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("広告（テスト表示）").font(DS.font(26, .black)).foregroundStyle(.white)
                Text(req.placement).font(DS.font(14, .bold)).foregroundStyle(.white.opacity(0.6))
                Image(systemName: "play.rectangle.fill").font(.system(size: 90)).foregroundStyle(.white.opacity(0.85))
                if left > 0 {
                    Text(req.rewarded ? "あと \(left) 秒で報酬ゲット" : "あと \(left) 秒").font(DS.font(18)).foregroundStyle(.yellow)
                } else {
                    Button(req.rewarded ? "報酬を受け取る" : "閉じる") { finish(true) }
                        .font(DS.font(20, .black)).foregroundStyle(.white).padding(.horizontal, 30).padding(.vertical, 12)
                        .background(Color.green, in: Capsule())
                }
            }
            VStack { HStack { Spacer()
                Button { finish(false) } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 32)).foregroundStyle(.white.opacity(0.6)) }.padding(20)
            }; Spacer() }
        }
        .onAppear {
            left = req.rewarded ? 5 : 3
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in Task { @MainActor in if left > 0 { left -= 1 } } }
        }
        .onDisappear { timer?.invalidate() }
    }
    private func finish(_ watched: Bool) {
        let ok = watched && left == 0
        AdService.shared.current = nil
        req.done(req.rewarded ? ok : true)
    }
}

// MARK: - 共通の小部品
struct MetaButton: View {
    let icon: String, title: String, color: Color, badge: Int
    let action: () -> Void
    var body: some View {
        Button(action: { AudioEngine.shared.play("tap"); action() }) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 24, weight: .bold))
                Text(title).font(DS.font(12, .bold))
            }
            .foregroundStyle(.white).frame(width: 72, height: 64)
            .background(LinearGradient(colors: [color.opacity(0.95), color.opacity(0.7)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.6), lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                if badge > 0 { Text("\(badge)").font(DS.font(13, .black)).foregroundStyle(.white).frame(width: 22, height: 22).background(Color.red, in: Circle()).offset(x: 6, y: -6) }
            }
        }
    }
}

struct SheetFrame<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var progress = Progress.shared
    var body: some View {
        NavigationStack {
            ScrollView { VStack(spacing: 14) { content }.padding() }
                .background(LinearGradient(colors: [Color(red: 0.3, green: 0.22, blue: 0.6), Color(red: 0.12, green: 0.12, blue: 0.32)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { GemCounter(value: progress.data.dna).fixedSize().scaleEffect(0.75) }
                    ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } }
                }
        }
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.2)))
    }
}

struct AdButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        if AdService.available { button }
    }
    private var button: some View {
        Button(action: action) {
            HStack(spacing: 6) { Image(systemName: "play.rectangle.fill"); Text(title) }
                .font(DS.font(16, .black)).foregroundStyle(.white).padding(.horizontal, 16).padding(.vertical, 10)
                .background(LinearGradient(colors: [Color(red: 1, green: 0.55, blue: 0.2), Color(red: 0.95, green: 0.3, blue: 0.4)], startPoint: .top, endPoint: .bottom), in: Capsule())
                .overlay(Capsule().stroke(DS.gold, lineWidth: 2))
        }
    }
}

// MARK: - ログインボーナス
struct LoginBonusView: View {
    @ObservedObject var meta = Meta.shared
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?
    var body: some View {
        VStack(spacing: 16) {
            Text("ログインボーナス").font(DS.font(28, .black)).foregroundStyle(.white)
            Text("連続 \(meta.d.loginStreak) 日目").font(DS.font(16, .bold)).foregroundStyle(DS.gold)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    let today = i == meta.loginDayIndex, past = i < meta.loginDayIndex
                    VStack(spacing: 2) {
                        Text("\(i + 1)日目").font(DS.font(11, .bold))
                        Text(i == 6 ? "🎁" : "💎").font(.system(size: 26))
                        Text(i == 6 ? "レア確定" : "\(Meta.loginRewards[i])").font(DS.font(12, .black))
                    }
                    .foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 78)
                    .background((today ? DS.gold : .white).opacity(today ? 0.45 : 0.12), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(today ? DS.gold : .clear, lineWidth: 3))
                    .overlay { if past { Image(systemName: "checkmark.circle.fill").font(.system(size: 28)).foregroundStyle(.green) } }
                }
            }
            if let message { Text(message).font(DS.font(18, .black)).foregroundStyle(.yellow).multilineTextAlignment(.center) }
            if meta.loginAvailable {
                AdButton(title: "広告を見て2倍で受け取る") {
                    AdService.shared.showRewarded("ログボ2倍") { ok in if ok { claim(true) } }
                }
                Button("受け取る") { claim(false) }.font(DS.font(16, .bold)).foregroundStyle(.white.opacity(0.85))
            } else {
                Button("OK") { dismiss() }.font(DS.font(20, .black)).foregroundStyle(.white).padding(.horizontal, 40).padding(.vertical, 10).background(Color.green, in: Capsule())
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Color(red: 0.35, green: 0.2, blue: 0.7), DS.navy], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }
    private func claim(_ doubled: Bool) {
        let (n, rare) = meta.claimLogin(doubled: doubled)
        AudioEngine.shared.play("win"); Haptics.shared.tap(1)
        message = "💎 +\(n)" + (rare.map { "\n🎉 \($0) をゲット！" } ?? "")
    }
}

// MARK: - デイリーミッション + 図鑑ボーナス
struct DailyView: View {
    @ObservedObject var meta = Meta.shared
    @ObservedObject var progress = Progress.shared
    var body: some View {
        SheetFrame(title: "デイリーミッション") {
            Text("毎日0時にリセット").font(DS.font(13, .bold)).foregroundStyle(.white.opacity(0.7))
            ForEach(meta.missions) { m in
                let p = meta.progress(m), done = p >= m.goal, claimed = meta.d.missionClaimed.contains(m.id)
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text(m.title).font(DS.font(17, .black)); Spacer(); Text("💎 \(m.reward)").font(DS.font(15, .black)) }
                        ProgressView(value: Double(p), total: Double(m.goal)).tint(done ? .green : .yellow)
                        HStack {
                            Text("\(p) / \(m.goal)").font(DS.font(13, .bold)).opacity(0.8)
                            Spacer()
                            if claimed { Text("受取済み ✓").font(DS.font(14, .bold)).foregroundStyle(.green) }
                            else if done {
                                AdButton(title: "2倍") { AdService.shared.showRewarded("ミッション2倍") { ok in if ok { meta.claimMission(m, doubled: true) } } }
                                Button("受け取る") { meta.claimMission(m, doubled: false); AudioEngine.shared.play("win") }.font(DS.font(15, .black))
                            }
                        }
                    }.foregroundStyle(.white)
                }
            }
            Text("図鑑ボーナス").font(DS.font(20, .black)).foregroundStyle(.white).padding(.top, 8)
            ForEach([Element.fire, .ice, .thunder, .none], id: \.self) { e in
                let found = (0..<4).filter { progress.data.discovered.contains("\(e.rawValue)-\($0)") }.count
                let claimed = meta.d.collectionRewards.contains(e.rawValue)
                Card {
                    HStack {
                        HStack(spacing: -10) { ForEach(0..<4, id: \.self) { k in Thumb(e: e, k: k, size: 40) } }
                        VStack(alignment: .leading) {
                            Text("\(e == .none ? "ノーマル" : e.rawValue.uppercased()) ライン").font(DS.font(15, .black))
                            Text("\(found) / 4 発見").font(DS.font(12, .bold)).opacity(0.8)
                        }
                        Spacer()
                        if claimed { Text("✓").font(DS.font(20, .black)).foregroundStyle(.green) }
                        else if meta.collectionReward(e) != nil { Button("💎300") { meta.claimCollection(e); AudioEngine.shared.play("win") }.font(DS.font(15, .black)) }
                        else { Text("💎300").font(DS.font(14, .bold)).opacity(0.5) }
                    }.foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - 宝箱
struct ChestView: View {
    @ObservedObject var meta = Meta.shared
    @State private var result: Meta.ChestResult?
    @State private var shake = false
    @State private var now = Date()
    let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        SheetFrame(title: "宝箱") {
            Text("🎁").font(.system(size: 120)).rotationEffect(.degrees(shake ? 8 : -8))
                .animation(.easeInOut(duration: 0.12).repeatCount(shake ? 6 : 0, autoreverses: true), value: shake)
            Text("10回に1回はレア（金色キャラ）確定！ あと \(10 - meta.d.chestsOpened % 10) 回").font(DS.font(14, .bold)).foregroundStyle(.yellow)
            // 排出率の表示（審査ガイドライン 3.1.1 ランダム報酬）。Meta.openChest の確率と一致させること
            Text("排出率：金色キャラ 8% ／ 強化レベルアップ 17% ／ DNA 60〜250 75%\n（金色キャラがコンプ済み・強化が最大の場合はDNAに置き換え。10回目ごとに金色キャラ確定）")
                .font(DS.font(11, .bold)).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            if let r = result {
                Card {
                    VStack(spacing: 6) {
                        Text("💎 +\(r.dna)").font(DS.font(24, .black))
                        if let s = r.shiny { Text("🌟 \(s) をゲット！").font(DS.font(18, .black)).foregroundStyle(DS.gold) }
                        if let u = r.upgrade { Text("⬆️ \(u) がレベルアップ！").font(DS.font(16, .black)).foregroundStyle(.green) }
                    }.frame(maxWidth: .infinity).foregroundStyle(.white)
                }
            }
            if meta.freeChestReady {
                bigButton("無料で開ける", .green) { open(.free) }
            } else {
                let r = Int(meta.freeChestRemaining)
                Text("次の無料まで \(r / 3600):" + String(format: "%02d:%02d", r % 3600 / 60, r % 60)).font(DS.font(15, .bold)).foregroundStyle(.white.opacity(0.8))
                AdButton(title: "広告を見て1個開ける") { AdService.shared.showRewarded("宝箱") { ok in if ok { open(.ad) } } }
            }
            bigButton("💎 \(Meta.chestCost) で開ける", .blue) { open(.dna) }
        }
        .onReceive(tick) { now = $0 }
    }
    private func bigButton(_ t: String, _ c: Color, _ a: @escaping () -> Void) -> some View {
        Button(action: a) { Text(t).font(DS.font(18, .black)).foregroundStyle(.white).frame(width: 240, height: 52).background(c, in: Capsule()) }
    }
    private func open(_ p: Meta.ChestPay) {
        shake.toggle(); Haptics.shared.rumble(0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            if let r = meta.openChest(p) { result = r; AudioEngine.shared.play(r.shiny != nil ? "evolve" : "win"); Haptics.shared.tap(1) }
        }
    }
}

// MARK: - 強化
struct UpgradeView: View {
    @ObservedObject var meta = Meta.shared
    @ObservedObject var progress = Progress.shared
    var body: some View {
        SheetFrame(title: "強化") {
            Text("負けても集めたDNAで強くなれる！").font(DS.font(14, .bold)).foregroundStyle(.yellow)
            ForEach(Meta.upgradeList) { u in
                let lv = meta.level(u.id), maxed = lv >= u.maxLevel, cost = u.cost(lv)
                Card {
                    HStack(spacing: 12) {
                        Image(systemName: u.icon).font(.system(size: 28)).frame(width: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(u.title)  Lv.\(lv)").font(DS.font(17, .black))
                            Text(u.detail).font(DS.font(12, .bold)).opacity(0.8)
                            Text(current(u)).font(DS.font(12, .bold)).foregroundStyle(.green)
                        }
                        Spacer()
                        Button { if meta.buy(u) { AudioEngine.shared.play("gate_big"); Haptics.shared.tap(0.8) } } label: {
                            Text(maxed ? "MAX" : "💎\(cost)").font(DS.font(15, .black)).foregroundStyle(.white).frame(width: 82, height: 40)
                                .background(maxed || progress.data.dna < cost ? Color.gray : Color.green, in: Capsule())
                        }.disabled(maxed || progress.data.dna < cost)
                    }.foregroundStyle(.white)
                }
            }
        }
    }
    private func current(_ u: Upgrade) -> String {
        switch u.id {
        case "start": return "いま: スタート \(meta.startCount) 体"
        case "power": return "いま: 攻撃力 ×" + String(format: "%.2f", meta.powerMultiplier)
        default: return "いま: 報酬 ×" + String(format: "%.1f", meta.dnaMultiplier)
        }
    }
}
