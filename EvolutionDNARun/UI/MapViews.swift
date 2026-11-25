import SwiftUI

// MARK: - ワールドマップ（下から上へ進む冒険の道・ワールドごとの風景つき）
struct MapView: View {
    var justCleared: Int? = nil
    var onPlay: (Int) -> Void
    var onClose: () -> Void
    @ObservedObject var progress = Progress.shared
    @State private var anim = false
    @State private var walker: Int = 0          // ドラゴンが立っているステージ
    @State private var hop = false
    @State private var banner: String?
    @State private var bannerSub: String?
    @State private var ready = false             // 歩き終わったら出発ボタンを強調
    private var current: Int { progress.data.currentStage }
    init(justCleared: Int? = nil, onPlay: @escaping (Int) -> Void, onClose: @escaping () -> Void) {
        self.justCleared = justCleared; self.onPlay = onPlay; self.onClose = onClose
        _walker = State(initialValue: justCleared ?? Progress.shared.data.currentStage)
    }
    static let finalStage = 60
    private var worldsTotal: Int { max(Self.finalStage / World.size, World.of(current) + 2) }
    static let goalH: CGFloat = 980
    private var remaining: Int { max(0, Self.finalStage - current + 1) }

    /// スクロール内容全体での座標
    private func globalPoint(_ n: Int, W: CGFloat) -> CGPoint {
        let w = World.of(max(1, n)), k = max(1, n) - w * World.size
        let p = point(k, W: W)
        return CGPoint(x: p.x, y: Self.goalH + CGFloat(worldsTotal - 1 - w) * Self.blockH + p.y)
    }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            ZStack(alignment: .top) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            GoalBlock(W: W, H: Self.goalH, remaining: remaining, anim: anim).id("goal")
                            ForEach((0..<worldsTotal).reversed(), id: \.self) { w in
                                worldBlock(w, W: W).id("w\(w)")
                            }
                            Rectangle().fill(MapTheme.sky(0).last!).frame(height: 200)
                        }
                        .overlay(alignment: .topLeading) { walkerView.position(globalPoint(walker, W: W)) }
                    }
                    .scrollIndicators(.hidden)
                    .onAppear {
                        anim = true
                        let target = "s\(walker)"
                        // 一度ゴールを見せてから現在地へ戻る（果てしなさの演出）
                        if justCleared == nil && !Self.seenGoal {
                            Self.seenGoal = true
                            proxy.scrollTo("goal", anchor: .top)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { withAnimation(.easeInOut(duration: 1.6)) { proxy.scrollTo(target, anchor: .center) } }
                        } else {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { withAnimation(.easeOut(duration: 0.4)) { proxy.scrollTo(target, anchor: .center) } }
                        }
                        if let c = justCleared { celebrate(c, proxy: proxy) } else { ready = true }
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 150).ignoresSafeArea(edges: .top).allowsHitTesting(false)
                VStack(spacing: 8) { header; goalMeter }
                if let banner { clearBanner(banner, bannerSub).padding(.top, 150).transition(.scale.combined(with: .opacity)) }
                startButton
            }
        }
        .background(Color(red: 0.08, green: 0.06, blue: 0.2).ignoresSafeArea())
    }
    nonisolated(unsafe) static var seenGoal = false

    /// クリア演出：クリアバナー → ドラゴンが次のマスへ跳ねて移動 → 出発ボタンが光る
    private func celebrate(_ c: Int, proxy: ScrollViewProxy) {
        AudioEngine.shared.play("win", volume: 0.8)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
            banner = "STAGE \(c) クリア！"
            bannerSub = c % World.size == 0 ? "WORLD \(World.of(c) + 2) 「\(World.name(World.of(c) + 1))」解放！" : "ゴールまで あと \(remaining) ステージ"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            let next = c + 1
            withAnimation(.easeInOut(duration: c % World.size == 0 ? 1.4 : 0.9)) { walker = next; proxy.scrollTo("s\(next)", anchor: .center) }
            withAnimation(.easeOut(duration: 0.22).repeatCount(4, autoreverses: true)) { hop = true }
            for i in 0..<4 { DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.24) { AudioEngine.shared.play("tap", volume: 0.6) } }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            hop = false
            AudioEngine.shared.play("gate_big", volume: 0.7); Haptics.shared.tap(0.7)
            withAnimation(.easeOut(duration: 0.3)) { banner = nil; ready = true }
        }
    }

    private var walkerView: some View {
        VStack(spacing: -4) {
            Text(walker == current ? "いまここ！" : "STAGE \(walker)").font(DS.font(12, .black)).foregroundStyle(DS.navy)
                .padding(.horizontal, 8).padding(.vertical, 2).background(.yellow, in: Capsule())
            Thumb(e: .fire, k: 0, size: 62)
        }
        .phaseAnimator([false, true]) { v, up in v.offset(y: up ? -8 : 0) } animation: { _ in .easeInOut(duration: 0.55) }
        .offset(y: hop ? -96 : -66)
        .shadow(color: .black.opacity(0.4), radius: 4, y: 4)
        .allowsHitTesting(false)
    }

    private func clearBanner(_ t: String, _ sub: String?) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) { ForEach(0..<3, id: \.self) { _ in Image(systemName: "star.fill") } }
                .font(.system(size: 26, weight: .black)).foregroundStyle(DS.gold).shadow(color: .orange, radius: 6)
            Text(t).font(DS.font(34, .black)).italic()
                .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.97, blue: 0.65), DS.goldDeep], startPoint: .top, endPoint: .bottom))
                .shadow(color: Color(red: 0.35, green: 0.12, blue: 0.05), radius: 0, x: 0, y: 3)
            if let sub { Text(sub).font(DS.font(15, .black)).foregroundStyle(.white) }
        }
        .padding(.horizontal, 26).padding(.vertical, 14)
        .background(LinearGradient(colors: [Color(red: 0.4, green: 0.2, blue: 0.75), DS.navy], startPoint: .top, endPoint: .bottom).opacity(0.95), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(DS.gold, lineWidth: 3))
        .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
        .allowsHitTesting(false)
    }

    private var header: some View {
        HStack {
            CircleIcon(icon: "house.fill") { onClose() }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: World.icon(World.of(current)))
                Text("WORLD \(World.of(current) + 1)")
            }
            .font(DS.font(17, .black)).foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 7)
            .background(LinearGradient(colors: [DS.navy, Color(red: 0.05, green: 0.08, blue: 0.25)], startPoint: .top, endPoint: .bottom), in: Capsule())
            .overlay(Capsule().stroke(DS.gold, lineWidth: 2.5))
            .shadow(color: .black.opacity(0.4), radius: 4, y: 3)
            Spacer()
            GemCounter(value: progress.data.dna).scaleEffect(0.8)
        }.padding(.horizontal, 12).padding(.top, 4)
    }

    /// 最終ゴールまでの道のり
    private var goalMeter: some View {
        let done = Double(min(Self.finalStage, current - 1)) / Double(Self.finalStage)
        return HStack(spacing: 8) {
            Thumb(e: .fire, k: 0, size: 26)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.black.opacity(0.45))
                    Capsule().fill(LinearGradient(colors: [Color(red: 0.5, green: 1, blue: 0.4), DS.gold], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(10, g.size.width * done))
                    ForEach(1..<(Self.finalStage / World.size), id: \.self) { i in
                        Circle().fill(.white.opacity(0.8)).frame(width: 5).position(x: g.size.width * CGFloat(i) / CGFloat(Self.finalStage / World.size), y: g.size.height / 2)
                    }
                }
            }.frame(height: 12).overlay(Capsule().stroke(.white.opacity(0.7), lineWidth: 1.5))
            VStack(spacing: -2) {
                Image(systemName: "crown.fill").font(.system(size: 18, weight: .black)).foregroundStyle(DS.gold)
                Text("あと\(remaining)").font(DS.font(11, .black)).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(DS.navy.opacity(0.8), in: Capsule())
        .padding(.horizontal, 20)
    }

    private var startButton: some View {
        VStack {
            Spacer()
            Button { AudioEngine.shared.play("tap"); onPlay(current) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill").font(.system(size: 30, weight: .black))
                    VStack(alignment: .leading, spacing: -2) {
                        Text(justCleared != nil ? "つぎへ！" : "出発！").font(DS.font(26, .black))
                        Text("STAGE \(current)\(current % World.size == 0 ? " 👑" : "")").font(DS.font(13, .bold)).opacity(0.9)
                    }
                }.foregroundStyle(.white).frame(width: 250, height: 80)
            }
            .buttonStyle(GameButtonStyle(top: Color(red: 0.55, green: 0.98, blue: 0.3), bottom: Color(red: 0.15, green: 0.72, blue: 0.15), radius: 40))
            .shadow(color: ready ? .yellow.opacity(0.8) : .black.opacity(0.45), radius: ready ? 18 : 10, y: 6)
            .scaleEffect(ready && anim ? 1.04 : 1)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: ready)
            .padding(.bottom, 24)
        }
    }

    // MARK: ワールド1区画
    static let blockH: CGFloat = 1120
    private static let topNodeY: CGFloat = 250
    private static let bottomNodeY: CGFloat = blockH - 90

    private func point(_ k: Int, W: CGFloat) -> CGPoint {
        let step = (Self.bottomNodeY - Self.topNodeY) / CGFloat(World.size - 1)
        let amp = min(115, W * 0.27)
        let x = W / 2 + (k == World.size ? 0 : CGFloat(sin(Double(k) * 1.1)) * amp)
        return CGPoint(x: x, y: Self.bottomNodeY - CGFloat(k - 1) * step)
    }

    private func worldBlock(_ w: Int, W: CGFloat) -> some View {
        let locked = w > World.of(current)
        let pts = (1...World.size).map { point($0, W: W) }
        let theme = w % MapTheme.count
        return ZStack(alignment: .topLeading) {
            MapScenery(theme: theme, seed: w, size: CGSize(width: W, height: Self.blockH), roadX: { y in roadX(y, pts: pts, W: W) })
            MapAmbient(theme: theme, W: W, H: Self.blockH, anim: anim)
            MapRoad(points: pts, W: W, H: Self.blockH)
            BossCastle(theme: theme, locked: locked)
                .frame(width: 210, height: 170)
                .position(x: pts[World.size - 1].x, y: pts[World.size - 1].y - 78)
            ForEach(1...World.size, id: \.self) { k in
                let n = w * World.size + k
                node(n).position(pts[k - 1])
            }
            WorldRibbon(index: w, name: World.name(w), icon: World.icon(w), theme: theme, locked: locked)
                .position(x: W / 2, y: 64)
        }
        .frame(width: W, height: Self.blockH)
        .clipped()
        // スクロール用アンカー：中心がノード位置に来る透明ビュー
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                ForEach(1...World.size, id: \.self) { k in
                    Color.clear.frame(width: 1, height: pts[k - 1].y * 2).id("s\(w * World.size + k)")
                }
            }.allowsHitTesting(false)
        }
        .overlay {
            if locked {
                ZStack {
                    Color.black.opacity(0.45)
                    VStack(spacing: 6) {
                        Image(systemName: "lock.fill").font(.system(size: 44, weight: .black))
                        Text("WORLD \(w) をクリアで解放").font(DS.font(16, .black))
                    }.foregroundStyle(.white.opacity(0.9))
                }.allowsHitTesting(false)
            }
        }
    }

    private func roadX(_ y: CGFloat, pts: [CGPoint], W: CGFloat) -> CGFloat {
        let all = [CGPoint(x: W / 2, y: Self.blockH)] + pts + [CGPoint(x: W / 2, y: 0)]
        for i in 0..<(all.count - 1) where y <= all[i].y && y >= all[i + 1].y {
            let t = (all[i].y - y) / max(1, all[i].y - all[i + 1].y)
            return all[i].x + (all[i + 1].x - all[i].x) * t
        }
        return W / 2
    }

    // MARK: ステージノード
    @ViewBuilder private func node(_ n: Int) -> some View {
        let cleared = progress.data.cleared.contains(n)
        let isCurrent = n == current
        let boss = n % World.size == 0
        let size: CGFloat = boss ? 80 : 58
        let fill: [Color] = cleared ? [Color(red: 1, green: 0.9, blue: 0.45), DS.goldDeep]
            : isCurrent ? [Color(red: 0.6, green: 1, blue: 0.35), Color(red: 0.1, green: 0.65, blue: 0.15)]
            : boss ? [Color(red: 0.75, green: 0.2, blue: 0.3), Color(red: 0.35, green: 0.05, blue: 0.15)]
            : [Color(white: 0.55), Color(white: 0.28)]
        Button {
            guard n <= current else { return }
            AudioEngine.shared.play("tap"); onPlay(n)
        } label: {
            ZStack {
                if isCurrent {
                    Circle().stroke(Color.yellow.opacity(0.8), lineWidth: 4)
                        .frame(width: size + 10, height: size + 10)
                        .scaleEffect(anim ? 1.45 : 1).opacity(anim ? 0 : 1)
                        .animation(.easeOut(duration: 1.3).repeatForever(autoreverses: false), value: anim)
                }
                // 台座（立体感）
                Ellipse().fill(.black.opacity(0.35)).frame(width: size * 1.05, height: size * 0.45).offset(y: size * 0.42)
                Circle().fill(LinearGradient(colors: [fill[1].opacity(0.9), .black.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                    .frame(width: size, height: size).offset(y: 5)
                Circle().fill(LinearGradient(colors: fill, startPoint: .top, endPoint: .bottom))
                    .frame(width: size, height: size)
                    .overlay(Circle().stroke(.white, lineWidth: isCurrent ? 5 : 3.5))
                    .overlay(Ellipse().fill(.white.opacity(0.35)).frame(width: size * 0.55, height: size * 0.22).offset(y: -size * 0.27))
                if boss {
                    Image(systemName: n > current ? "lock.fill" : "crown.fill")
                        .font(.system(size: n > current ? 22 : 30, weight: .black))
                        .foregroundStyle(n > current ? .white.opacity(0.75) : .yellow)
                        .shadow(color: .black.opacity(0.5), radius: 1, y: 2)
                } else if n > current {
                    Image(systemName: "lock.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(.white.opacity(0.75))
                } else {
                    Text("\(n)").font(DS.font(24, .black)).foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 0, x: 0, y: 2)
                }
            }
            .frame(width: size + 20, height: size + 20)
            .shadow(color: isCurrent ? .yellow.opacity(0.9) : .clear, radius: 14)
            .overlay(alignment: .bottom) {
                VStack(spacing: 2) {
                    if cleared {
                        HStack(spacing: 0) {
                            ForEach(0..<3, id: \.self) { _ in Image(systemName: "star.fill") }
                        }.font(.system(size: 11, weight: .black)).foregroundStyle(.yellow)
                        .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                    }
                    if boss {
                        Text("大ボス").font(DS.font(12, .black)).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 1)
                            .background(Color.red, in: Capsule()).overlay(Capsule().stroke(.white, lineWidth: 1.5))
                    }
                }.offset(y: 16)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - テーマ
enum MapTheme {
    static let count = 6
    /// 空の上→下
    static func sky(_ t: Int) -> [Color] {
        switch t {
        case 0: return [Color(red: 0.42, green: 0.78, blue: 1), Color(red: 0.7, green: 0.93, blue: 0.85), Color(red: 0.4, green: 0.78, blue: 0.35)]
        case 1: return [Color(red: 0.1, green: 0.55, blue: 0.85), Color(red: 0.08, green: 0.3, blue: 0.65), Color(red: 0.05, green: 0.12, blue: 0.38)]
        case 2: return [Color(red: 0.25, green: 0.05, blue: 0.12), Color(red: 0.6, green: 0.12, blue: 0.1), Color(red: 0.95, green: 0.42, blue: 0.12)]
        case 3: return [Color(red: 0.55, green: 0.78, blue: 1), Color(red: 0.82, green: 0.94, blue: 1), Color(red: 0.6, green: 0.8, blue: 0.95)]
        case 4: return [Color(red: 0.2, green: 0.1, blue: 0.38), Color(red: 0.45, green: 0.28, blue: 0.6), Color(red: 0.95, green: 0.72, blue: 0.35)]
        default: return [Color(red: 0.02, green: 0.02, blue: 0.1), Color(red: 0.15, green: 0.06, blue: 0.35), Color(red: 0.05, green: 0.1, blue: 0.3)]
        }
    }
    static func accent(_ t: Int) -> Color {
        [Color(red: 0.25, green: 0.7, blue: 0.3), Color(red: 0.2, green: 0.85, blue: 0.9), Color(red: 1, green: 0.4, blue: 0.1),
         Color(red: 0.4, green: 0.75, blue: 1), Color(red: 1, green: 0.85, blue: 0.2), Color(red: 0.7, green: 0.4, blue: 1)][t % count]
    }
}

/// 決定的な乱数（毎フレーム再計算しても形が変わらない）
private struct SeededRNG {
    var s: UInt64
    init(_ seed: Int) { s = (UInt64(truncatingIfNeeded: seed) &* 2654435761 &+ 0x9E3779B97F4A7C15) | 1 }
    mutating func next() -> CGFloat {
        s ^= s << 13; s ^= s >> 7; s ^= s << 17
        return CGFloat(s % 10_000) / 10_000
    }
}

// MARK: - 静的な風景（Canvasで一括描画）
private struct MapScenery: View {
    let theme: Int, seed: Int, size: CGSize
    let roadX: (CGFloat) -> CGFloat

    var body: some View {
        Canvas { ctx, sz in
            let W = sz.width, H = sz.height
            var rng = SeededRNG(seed * 31 + 7)
            ctx.fill(Path(CGRect(origin: .zero, size: sz)),
                     with: .linearGradient(Gradient(colors: MapTheme.sky(theme)), startPoint: .zero, endPoint: CGPoint(x: 0, y: H)))
            switch theme {
            case 0: paradise(&ctx, W, H, &rng)
            case 1: cellSea(&ctx, W, H, &rng)
            case 2: volcano(&ctx, W, H, &rng)
            case 3: glacier(&ctx, W, H, &rng)
            case 4: thunder(&ctx, W, H, &rng)
            default: space(&ctx, W, H, &rng)
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    // 道から離れた位置に置く
    private func sideX(_ y: CGFloat, _ W: CGFloat, _ rng: inout SeededRNG, gap: CGFloat = 70) -> CGFloat {
        let rx = roadX(y)
        let left = rng.next() < 0.5
        let lo = left ? 14 : rx + gap, hi = left ? rx - gap : W - 14
        if hi - lo < 10 { return left ? W - 30 : 30 }
        return lo + (hi - lo) * rng.next()
    }

    private func ridge(_ W: CGFloat, base: CGFloat, amp: CGFloat, freq: Double, phase: Double, H: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: H))
            var x: CGFloat = 0
            while x <= W + 8 {
                let y = base - amp * CGFloat(0.6 * sin(Double(x) / W * freq + phase) + 0.4 * sin(Double(x) / W * freq * 2.3 + phase * 1.7))
                p.addLine(to: CGPoint(x: x, y: y)); x += 8
            }
            p.addLine(to: CGPoint(x: W, y: H)); p.closeSubpath()
        }
    }

    private func blob(_ c: CGPoint, _ r: CGFloat) -> Path { Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)) }

    private func glow(_ ctx: inout GraphicsContext, _ c: CGPoint, _ r: CGFloat, _ col: Color) {
        ctx.fill(blob(c, r), with: .radialGradient(Gradient(colors: [col, col.opacity(0)]), center: c, startRadius: 0, endRadius: r))
    }

    // ---- 0: はじまりの楽園
    private func paradise(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ rng: inout SeededRNG) {
        glow(&ctx, CGPoint(x: W * 0.82, y: 150), 140, Color(red: 1, green: 0.95, blue: 0.6).opacity(0.9))
        ctx.fill(blob(CGPoint(x: W * 0.82, y: 150), 38), with: .color(Color(red: 1, green: 0.97, blue: 0.75)))
        ctx.fill(ridge(W, base: 300, amp: 60, freq: 7, phase: 1, H: H), with: .color(Color(red: 0.45, green: 0.7, blue: 0.75).opacity(0.7)))
        ctx.fill(ridge(W, base: 360, amp: 40, freq: 9, phase: 3, H: H), with: .color(Color(red: 0.4, green: 0.72, blue: 0.45)))
        ctx.fill(ridge(W, base: 520, amp: 35, freq: 5, phase: 2, H: H), with: .color(Color(red: 0.35, green: 0.68, blue: 0.32)))
        ctx.fill(ridge(W, base: 760, amp: 30, freq: 6, phase: 4, H: H), with: .color(Color(red: 0.3, green: 0.62, blue: 0.27)))
        // 草の斑点
        for _ in 0..<40 {
            let p = CGPoint(x: rng.next() * W, y: 420 + rng.next() * (H - 420))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x, y: p.y, width: 26, height: 9)), with: .color(Color(red: 0.5, green: 0.82, blue: 0.4).opacity(0.6)))
        }
        // 木
        for i in 0..<16 {
            let y = 400 + CGFloat(i) / 16 * (H - 440) + rng.next() * 30
            let x = sideX(y, W, &rng)
            let s = 0.8 + rng.next() * 0.6
            ctx.fill(Path(ellipseIn: CGRect(x: x - 20 * s, y: y + 22 * s, width: 40 * s, height: 10 * s)), with: .color(.black.opacity(0.2)))
            ctx.fill(Path(roundedRect: CGRect(x: x - 4 * s, y: y, width: 8 * s, height: 26 * s), cornerRadius: 3), with: .color(Color(red: 0.5, green: 0.3, blue: 0.15)))
            ctx.fill(blob(CGPoint(x: x, y: y - 6 * s), 22 * s), with: .color(Color(red: 0.15, green: 0.5, blue: 0.2)))
            ctx.fill(blob(CGPoint(x: x - 9 * s, y: y - 2 * s), 14 * s), with: .color(Color(red: 0.2, green: 0.6, blue: 0.25)))
            ctx.fill(blob(CGPoint(x: x + 6 * s, y: y - 14 * s), 12 * s), with: .color(Color(red: 0.4, green: 0.78, blue: 0.35)))
        }
        // 花
        let flowers: [Color] = [.pink, .yellow, .white, .orange]
        for _ in 0..<30 {
            let y = 430 + rng.next() * (H - 450)
            let x = sideX(y, W, &rng, gap: 40)
            ctx.fill(blob(CGPoint(x: x, y: y), 4), with: .color(flowers[Int(rng.next() * 4) % 4]))
        }
    }

    // ---- 1: ふしぎ細胞の海
    private func cellSea(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ rng: inout SeededRNG) {
        for i in 0..<5 {   // 光の筋
            let x = CGFloat(i) * W / 4 + rng.next() * 30
            ctx.fill(Path { p in p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x + 50, y: 0)); p.addLine(to: CGPoint(x: x + 160, y: H * 0.7)); p.addLine(to: CGPoint(x: x + 60, y: H * 0.7)) },
                     with: .linearGradient(Gradient(colors: [.white.opacity(0.18), .clear]), startPoint: CGPoint(x: x, y: 0), endPoint: CGPoint(x: x, y: H * 0.7)))
        }
        // 大きな細胞
        for _ in 0..<14 {
            let y = 160 + rng.next() * (H - 180)
            let x = sideX(y, W, &rng, gap: 55)
            let r = 16 + rng.next() * 26
            let hue = [Color(red: 0.4, green: 1, blue: 0.8), Color(red: 1, green: 0.5, blue: 0.8), Color(red: 0.7, green: 0.6, blue: 1)][Int(rng.next() * 3) % 3]
            ctx.fill(blob(CGPoint(x: x, y: y), r), with: .radialGradient(Gradient(colors: [hue.opacity(0.15), hue.opacity(0.55)]), center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
            ctx.stroke(blob(CGPoint(x: x, y: y), r), with: .color(hue.opacity(0.9)), lineWidth: 2.5)
            ctx.fill(blob(CGPoint(x: x + r * 0.2, y: y - r * 0.1), r * 0.32), with: .color(hue.opacity(0.9)))
            ctx.fill(blob(CGPoint(x: x - r * 0.4, y: y - r * 0.45), r * 0.15), with: .color(.white.opacity(0.7)))
        }
        // 海藻
        for i in 0..<12 {
            let y = 300 + CGFloat(i) / 12 * (H - 320)
            let x = sideX(y, W, &rng)
            var p = Path(); p.move(to: CGPoint(x: x, y: y))
            for j in 1...5 { p.addLine(to: CGPoint(x: x + CGFloat(j % 2 == 0 ? -8 : 8), y: y - CGFloat(j) * 14)) }
            ctx.stroke(p, with: .color(Color(red: 0.2, green: 0.8, blue: 0.5)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        }
        for _ in 0..<50 {   // 泡
            let c = CGPoint(x: rng.next() * W, y: rng.next() * H), r = 2 + rng.next() * 6
            ctx.stroke(blob(c, r), with: .color(.white.opacity(0.45)), lineWidth: 1.5)
        }
    }

    // ---- 2: マグマ火山
    private func volcano(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ rng: inout SeededRNG) {
        // 巨大火山
        let peak = CGPoint(x: W * 0.5, y: 190)
        glow(&ctx, CGPoint(x: peak.x, y: peak.y - 10), 180, Color(red: 1, green: 0.45, blue: 0.1).opacity(0.8))
        let cone = Path { p in
            p.move(to: CGPoint(x: -40, y: 560)); p.addLine(to: CGPoint(x: peak.x - 50, y: peak.y))
            p.addLine(to: CGPoint(x: peak.x + 50, y: peak.y)); p.addLine(to: CGPoint(x: W + 40, y: 560)); p.closeSubpath()
        }
        ctx.fill(cone, with: .linearGradient(Gradient(colors: [Color(red: 0.3, green: 0.1, blue: 0.12), Color(red: 0.15, green: 0.05, blue: 0.08)]), startPoint: peak, endPoint: CGPoint(x: peak.x, y: 560)))
        // 溶岩の筋
        for dx in [-30.0, 5.0, 35.0] {
            var p = Path(); p.move(to: CGPoint(x: peak.x + dx * 0.6, y: peak.y + 2))
            p.addQuadCurve(to: CGPoint(x: peak.x + dx * 4, y: 480), control: CGPoint(x: peak.x + dx * 2.5, y: 300))
            ctx.stroke(p, with: .linearGradient(Gradient(colors: [.yellow, .orange, .red.opacity(0)]), startPoint: peak, endPoint: CGPoint(x: peak.x, y: 480)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: peak.x - 50, y: peak.y - 10, width: 100, height: 20)), with: .color(Color(red: 1, green: 0.8, blue: 0.2)))
        // 地面
        ctx.fill(ridge(W, base: 600, amp: 30, freq: 6, phase: 1, H: H), with: .color(Color(red: 0.28, green: 0.12, blue: 0.12)))
        ctx.fill(ridge(W, base: 820, amp: 25, freq: 8, phase: 2, H: H), with: .color(Color(red: 0.22, green: 0.09, blue: 0.1)))
        // 溶岩の川（ひび）
        for _ in 0..<10 {
            let y = 620 + rng.next() * (H - 640)
            let x = sideX(y, W, &rng, gap: 50)
            var p = Path(); p.move(to: CGPoint(x: x, y: y))
            for j in 1...4 { p.addLine(to: CGPoint(x: x + CGFloat(j) * 14, y: y + (j % 2 == 0 ? -6 : 6))) }
            ctx.stroke(p, with: .color(Color(red: 1, green: 0.55, blue: 0.1)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        // 岩
        for i in 0..<14 {
            let y = 580 + CGFloat(i) / 14 * (H - 600)
            let x = sideX(y, W, &rng), s = 14 + rng.next() * 16
            let rock = Path { p in p.move(to: CGPoint(x: x - s, y: y)); p.addLine(to: CGPoint(x: x - s * 0.6, y: y - s * 0.9)); p.addLine(to: CGPoint(x: x + s * 0.3, y: y - s * 1.1)); p.addLine(to: CGPoint(x: x + s, y: y - s * 0.3)); p.addLine(to: CGPoint(x: x + s * 0.9, y: y)); p.closeSubpath() }
            ctx.fill(rock, with: .color(Color(red: 0.12, green: 0.06, blue: 0.08)))
            ctx.stroke(rock, with: .color(Color(red: 1, green: 0.4, blue: 0.1).opacity(0.7)), lineWidth: 1.5)
        }
    }

    // ---- 3: こおりの氷河
    private func glacier(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ rng: inout SeededRNG) {
        func peaks(_ base: CGFloat, _ h: CGFloat, _ n: Int, _ col: Color, _ cap: Bool) {
            let w = W / CGFloat(n)
            for i in 0...n {
                let cx = CGFloat(i) * w + rng.next() * 20 - 10, ph = h * (0.7 + rng.next() * 0.5)
                let tri = Path { p in p.move(to: CGPoint(x: cx - w * 0.8, y: base)); p.addLine(to: CGPoint(x: cx, y: base - ph)); p.addLine(to: CGPoint(x: cx + w * 0.8, y: base)); p.closeSubpath() }
                ctx.fill(tri, with: .color(col))
                if cap {
                    let c = Path { p in p.move(to: CGPoint(x: cx - w * 0.26, y: base - ph * 0.68)); p.addLine(to: CGPoint(x: cx, y: base - ph)); p.addLine(to: CGPoint(x: cx + w * 0.26, y: base - ph * 0.68)); p.addLine(to: CGPoint(x: cx + 4, y: base - ph * 0.6)); p.closeSubpath() }
                    ctx.fill(c, with: .color(.white))
                }
            }
            ctx.fill(Path(CGRect(x: 0, y: base, width: W, height: H - base)), with: .color(col))
        }
        peaks(380, 220, 3, Color(red: 0.6, green: 0.72, blue: 0.92), true)
        peaks(560, 140, 4, Color(red: 0.75, green: 0.87, blue: 0.98), true)
        ctx.fill(ridge(W, base: 700, amp: 20, freq: 5, phase: 1, H: H), with: .color(Color(red: 0.9, green: 0.96, blue: 1)))
        // 氷の結晶柱
        for i in 0..<14 {
            let y = 620 + CGFloat(i) / 14 * (H - 640)
            let x = sideX(y, W, &rng), s = 0.7 + rng.next() * 0.8
            for (dx, hh) in [(-10.0, 30.0), (0, 50), (11, 36)] {
                let cx = x + CGFloat(dx) * s, top = y - CGFloat(hh) * s
                let c = Path { p in p.move(to: CGPoint(x: cx - 7 * s, y: y)); p.addLine(to: CGPoint(x: cx - 7 * s, y: top + 10 * s)); p.addLine(to: CGPoint(x: cx, y: top)); p.addLine(to: CGPoint(x: cx + 7 * s, y: top + 10 * s)); p.addLine(to: CGPoint(x: cx + 7 * s, y: y)); p.closeSubpath() }
                ctx.fill(c, with: .linearGradient(Gradient(colors: [Color(red: 0.85, green: 0.97, blue: 1), Color(red: 0.35, green: 0.65, blue: 0.95)]), startPoint: CGPoint(x: cx - 7, y: top), endPoint: CGPoint(x: cx + 7, y: y)))
                ctx.stroke(c, with: .color(.white.opacity(0.9)), lineWidth: 1.2)
            }
        }
        for _ in 0..<60 { ctx.fill(blob(CGPoint(x: rng.next() * W, y: rng.next() * H), 1.5 + rng.next() * 2), with: .color(.white.opacity(0.85))) }
    }

    // ---- 4: カミナリ雲の峰
    private func thunder(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ rng: inout SeededRNG) {
        func cloud(_ c: CGPoint, _ s: CGFloat, _ col: Color) {
            for (dx, dy, r) in [(-1.0, 0.2, 0.55), (-0.4, -0.25, 0.75), (0.35, -0.15, 0.65), (0.95, 0.2, 0.5), (0, 0.3, 0.6)] {
                ctx.fill(blob(CGPoint(x: c.x + CGFloat(dx) * s, y: c.y + CGFloat(dy) * s), CGFloat(r) * s), with: .color(col))
            }
        }
        cloud(CGPoint(x: W * 0.2, y: 180), 80, Color(red: 0.3, green: 0.2, blue: 0.45))
        cloud(CGPoint(x: W * 0.85, y: 220), 90, Color(red: 0.35, green: 0.25, blue: 0.5))
        // 稲妻
        for i in 0..<3 {
            var p = Path(); var pt = CGPoint(x: W * (0.15 + CGFloat(i) * 0.35), y: 230 + CGFloat(i % 2) * 20)
            p.move(to: pt)
            for j in 0..<6 { pt = CGPoint(x: pt.x + (j % 2 == 0 ? 18 : -12) + rng.next() * 8, y: pt.y + 28 + rng.next() * 14); p.addLine(to: pt) }
            ctx.stroke(p, with: .color(.yellow.opacity(0.35)), style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
            ctx.stroke(p, with: .color(Color(red: 1, green: 1, blue: 0.75)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
        // 浮島
        for i in 0..<9 {
            let y = 480 + CGFloat(i) / 9 * (H - 520)
            let x = sideX(y, W, &rng, gap: 80), s = 22 + rng.next() * 14
            let isle = Path { p in p.move(to: CGPoint(x: x - s, y: y)); p.addLine(to: CGPoint(x: x + s, y: y)); p.addLine(to: CGPoint(x: x + s * 0.4, y: y + s * 0.9)); p.addLine(to: CGPoint(x: x, y: y + s * 1.5)); p.addLine(to: CGPoint(x: x - s * 0.5, y: y + s * 0.8)); p.closeSubpath() }
            ctx.fill(isle, with: .color(Color(red: 0.35, green: 0.22, blue: 0.3)))
            ctx.fill(Path(roundedRect: CGRect(x: x - s, y: y - 6, width: s * 2, height: 9), cornerRadius: 4), with: .color(Color(red: 0.55, green: 0.8, blue: 0.4)))
            ctx.fill(blob(CGPoint(x: x + s * 0.3, y: y - 4), 5), with: .color(.yellow))
        }
        // 下層の雲海
        for i in 0..<8 { cloud(CGPoint(x: CGFloat(i) * W / 6, y: H - 40 - CGFloat(i % 2) * 30), 50, Color(red: 0.95, green: 0.85, blue: 0.7).opacity(0.85)) }
        for i in 0..<6 { cloud(CGPoint(x: CGFloat(i) * W / 4 + 20, y: 560 + CGFloat(i % 3) * 140), 30, .white.opacity(0.3)) }
    }

    // ---- 5: ほしぞら宇宙
    private func space(_ ctx: inout GraphicsContext, _ W: CGFloat, _ H: CGFloat, _ rng: inout SeededRNG) {
        glow(&ctx, CGPoint(x: W * 0.2, y: H * 0.35), 220, Color(red: 0.9, green: 0.3, blue: 0.8).opacity(0.35))
        glow(&ctx, CGPoint(x: W * 0.8, y: H * 0.7), 240, Color(red: 0.2, green: 0.6, blue: 1).opacity(0.3))
        for _ in 0..<140 { ctx.fill(blob(CGPoint(x: rng.next() * W, y: rng.next() * H), 0.6 + rng.next() * 1.6), with: .color(.white.opacity(0.4 + rng.next() * 0.6))) }
        // 環のある惑星
        let pc = CGPoint(x: W * 0.78, y: 260)
        ctx.fill(blob(pc, 58), with: .linearGradient(Gradient(colors: [Color(red: 1, green: 0.7, blue: 0.4), Color(red: 0.75, green: 0.25, blue: 0.45)]), startPoint: CGPoint(x: pc.x - 58, y: pc.y - 58), endPoint: CGPoint(x: pc.x + 58, y: pc.y + 58)))
        var ring = Path(ellipseIn: CGRect(x: pc.x - 100, y: pc.y - 18, width: 200, height: 36))
        ring = ring.applying(CGAffineTransform(translationX: -pc.x, y: -pc.y).concatenating(CGAffineTransform(rotationAngle: -0.3)).concatenating(CGAffineTransform(translationX: pc.x, y: pc.y)))
        ctx.stroke(ring, with: .color(Color(red: 1, green: 0.9, blue: 0.7).opacity(0.85)), lineWidth: 6)
        // 小さな惑星・月
        let moons: [(CGFloat, CGFloat, CGFloat, Color)] = [(0.15, 520, 30, Color(red: 0.4, green: 0.8, blue: 1)), (0.85, 760, 22, Color(red: 0.5, green: 1, blue: 0.6)), (0.12, 940, 18, Color(red: 1, green: 0.9, blue: 0.4))]
        for (fx, y, r, col) in moons {
            let c = CGPoint(x: W * fx, y: y)
            glow(&ctx, c, r * 2, col.opacity(0.4))
            ctx.fill(blob(c, r), with: .linearGradient(Gradient(colors: [col, col.opacity(0.4)]), startPoint: CGPoint(x: c.x - r, y: c.y - r), endPoint: CGPoint(x: c.x + r, y: c.y + r)))
        }
        // 小惑星
        for i in 0..<10 {
            let y = 380 + CGFloat(i) / 10 * (H - 400)
            let x = sideX(y, W, &rng), s = 6 + rng.next() * 10
            ctx.fill(Path(ellipseIn: CGRect(x: x - s, y: y - s * 0.7, width: s * 2, height: s * 1.4)), with: .color(Color(red: 0.45, green: 0.4, blue: 0.55)))
            ctx.fill(blob(CGPoint(x: x - s * 0.3, y: y - s * 0.2), s * 0.25), with: .color(Color(red: 0.3, green: 0.25, blue: 0.4)))
        }
    }
}

// MARK: - 動きのある装飾（雲の流れ・キラキラ）。repeatForeverアニメのみで毎フレーム計算なし
private struct MapAmbient: View {
    let theme: Int, W: CGFloat, H: CGFloat, anim: Bool
    var body: some View {
        ZStack(alignment: .topLeading) {
            if theme == 0 || theme == 3 || theme == 4 {
                ForEach(0..<3, id: \.self) { i in
                    CloudPuff(color: theme == 4 ? Color(red: 0.85, green: 0.75, blue: 0.95) : .white)
                        .frame(width: 110 - CGFloat(i) * 15, height: 46)
                        .opacity(0.85)
                        .position(x: anim ? W + 80 : -80, y: 200 + CGFloat(i) * 300)
                        .animation(.linear(duration: 28 + Double(i) * 9).repeatForever(autoreverses: false).delay(Double(i) * -6), value: anim)
                }
            }
            if theme == 1 {
                ForEach(0..<6, id: \.self) { i in
                    Circle().stroke(.white.opacity(0.6), lineWidth: 2).frame(width: 10 + CGFloat(i % 3) * 5)
                        .position(x: W * (0.1 + CGFloat(i) * 0.16), y: anim ? 80 : H - 50)
                        .animation(.linear(duration: 12 + Double(i) * 2).repeatForever(autoreverses: false), value: anim)
                }
            }
            if theme == 2 {
                ForEach(0..<8, id: \.self) { i in
                    Circle().fill(Color(red: 1, green: 0.6, blue: 0.15)).frame(width: 5, height: 5)
                        .shadow(color: .orange, radius: 4)
                        .position(x: W * (0.35 + CGFloat(i % 4) * 0.1), y: anim ? 60 : 230)
                        .opacity(anim ? 0 : 1)
                        .animation(.easeOut(duration: 2.2 + Double(i) * 0.3).repeatForever(autoreverses: false), value: anim)
                }
            }
            if theme == 3 || theme == 5 || theme == 1 {
                ForEach(0..<9, id: \.self) { i in
                    Image(systemName: "sparkle").font(.system(size: CGFloat(10 + (i * 7) % 12), weight: .bold))
                        .foregroundStyle(.white)
                        .position(x: W * CGFloat((i * 37 + 11) % 100) / 100, y: H * CGFloat((i * 53 + 17) % 100) / 100)
                        .opacity(anim ? 0.15 : 1).scaleEffect(anim ? 0.6 : 1.1)
                        .animation(.easeInOut(duration: 1.1 + Double(i % 4) * 0.35).repeatForever(autoreverses: true), value: anim)
                }
            }
            if theme == 4 {
                Rectangle().fill(.white).opacity(anim ? 0 : 0.12)
                    .animation(.easeIn(duration: 0.25).delay(3).repeatForever(autoreverses: true), value: anim)
            }
        }
        .frame(width: W, height: H)
        .allowsHitTesting(false)
    }
}

private struct CloudPuff: View {
    let color: Color
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                Capsule().frame(width: w, height: h * 0.55).offset(y: h * 0.2)
                Circle().frame(width: h * 0.8).offset(x: -w * 0.18, y: 0)
                Circle().frame(width: h).offset(x: w * 0.1, y: -h * 0.1)
            }.foregroundStyle(color).frame(width: w, height: h)
        }
    }
}

// MARK: - 太い道
private struct MapRoad: View {
    let points: [CGPoint], W: CGFloat, H: CGFloat
    var body: some View {
        let all = [CGPoint(x: W / 2, y: H + 10)] + points + [CGPoint(x: W / 2, y: -10)]
        let path = Path { p in
            p.move(to: all[0])
            for i in 1..<all.count {
                let a = all[i - 1], b = all[i]
                let midY = (a.y + b.y) / 2
                p.addCurve(to: b, control1: CGPoint(x: a.x, y: midY), control2: CGPoint(x: b.x, y: midY))
            }
        }
        ZStack {
            path.stroke(.black.opacity(0.3), style: StrokeStyle(lineWidth: 40, lineCap: .round, lineJoin: .round)).offset(y: 6)
            path.stroke(Color(red: 0.45, green: 0.28, blue: 0.15), style: StrokeStyle(lineWidth: 38, lineCap: .round, lineJoin: .round))
            path.stroke(LinearGradient(colors: [Color(red: 1, green: 0.9, blue: 0.65), Color(red: 0.92, green: 0.75, blue: 0.48)], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 28, lineCap: .round, lineJoin: .round))
            path.stroke(.white.opacity(0.75), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [3, 15]))
        }
        .frame(width: W, height: H)
        .allowsHitTesting(false)
    }
}

// MARK: - ボスの城門
private struct BossCastle: View {
    let theme: Int, locked: Bool
    var body: some View {
        let stone: [Color] = theme == 3 ? [Color(red: 0.75, green: 0.88, blue: 1), Color(red: 0.4, green: 0.55, blue: 0.85)]
            : theme == 2 ? [Color(red: 0.4, green: 0.15, blue: 0.15), Color(red: 0.18, green: 0.05, blue: 0.08)]
            : [Color(red: 0.5, green: 0.45, blue: 0.6), Color(red: 0.22, green: 0.18, blue: 0.32)]
        let grad = LinearGradient(colors: stone, startPoint: .top, endPoint: .bottom)
        let acc = MapTheme.accent(theme)
        ZStack(alignment: .bottom) {
            Circle().fill(RadialGradient(colors: [acc.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 110)).frame(width: 230, height: 230).offset(y: 40)
            HStack(alignment: .bottom, spacing: 0) {
                tower(grad, acc, h: 120)
                ZStack(alignment: .top) {
                    Rectangle().fill(grad).frame(width: 110, height: 92)
                    HStack(spacing: 8) { ForEach(0..<5, id: \.self) { _ in Rectangle().fill(stone[0]).frame(width: 14, height: 12) } }.offset(y: -11)
                }
                tower(grad, acc, h: 120)
            }
            // 門
            UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30)
                .fill(LinearGradient(colors: [.black, Color(red: 0.25, green: 0.05, blue: 0.1)], startPoint: .top, endPoint: .bottom))
                .frame(width: 60, height: 64)
                .overlay(alignment: .top) { HStack(spacing: 10) { ForEach(0..<2, id: \.self) { _ in Circle().fill(locked ? Color.gray : Color.red).frame(width: 9).shadow(color: .red, radius: locked ? 0 : 5) } }.padding(.top, 20) }
            // 旗
            Image(systemName: "flag.fill").font(.system(size: 22, weight: .black)).foregroundStyle(Color.red)
                .offset(x: 6, y: -150)
        }
        .shadow(color: .black.opacity(0.35), radius: 6, y: 6)
        .allowsHitTesting(false)
    }
    private func tower(_ g: LinearGradient, _ acc: Color, h: CGFloat) -> some View {
        VStack(spacing: 0) {
            Triangle().fill(LinearGradient(colors: [acc, acc.opacity(0.6)], startPoint: .top, endPoint: .bottom)).frame(width: 52, height: 40)
            Rectangle().fill(g).frame(width: 42, height: h)
                .overlay(alignment: .top) { Capsule().fill(Color.yellow.opacity(locked ? 0.2 : 0.9)).frame(width: 8, height: 16).padding(.top, 18) }
        }
    }
}

private struct Triangle: Shape {
    func path(in r: CGRect) -> Path { Path { p in p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.closeSubpath() } }
}

// MARK: - リボン型のワールド看板
private struct WorldRibbon: View {
    let index: Int, name: String, icon: String, theme: Int, locked: Bool
    var body: some View {
        let acc = locked ? Color.gray : MapTheme.accent(theme)
        ZStack {
            HStack(spacing: 230) { tail(acc, flip: false); tail(acc, flip: true) }.offset(y: 14)
            VStack(spacing: 0) {
                Text("WORLD \(index + 1)").font(DS.font(13, .black)).foregroundStyle(.white.opacity(0.9))
                HStack(spacing: 6) {
                    Image(systemName: icon)
                    Text(name)
                }.font(DS.font(22, .black)).foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 0, x: 0, y: 2)
            }
            .frame(width: 260, height: 62)
            .background(LinearGradient(colors: [acc.mix(.white, 0.25), acc.mix(.black, 0.3)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.gold, lineWidth: 3))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.4), lineWidth: 1.5).padding(5))
        }
        .shadow(color: .black.opacity(0.45), radius: 6, y: 5)
        .allowsHitTesting(false)
    }
    private func tail(_ c: Color, flip: Bool) -> some View {
        RibbonTail().fill(c.mix(.black, 0.45)).frame(width: 46, height: 44).scaleEffect(x: flip ? -1 : 1)
    }
}

private struct RibbonTail: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX + r.width * 0.35, y: r.midY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.closeSubpath()
        }
    }
}

private extension Color {
    func mix(_ o: Color, _ t: Double) -> Color {
        let a = UIColor(self), b = UIColor(o)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0, r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1); b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let f = CGFloat(t)
        return Color(red: r1 + (r2 - r1) * f, green: g1 + (g2 - g1) * f, blue: b1 + (b2 - b1) * f)
    }
}

// MARK: - 最終ゴール（雲の上にそびえる伝説の神殿。はるか遠くに見える）
private struct GoalBlock: View {
    let W: CGFloat, H: CGFloat, remaining: Int, anim: Bool
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(red: 0.03, green: 0.01, blue: 0.12), Color(red: 0.2, green: 0.06, blue: 0.4), Color(red: 0.55, green: 0.25, blue: 0.6), Color(red: 0.95, green: 0.6, blue: 0.5)],
                           startPoint: .top, endPoint: .bottom)
            // 星空
            Canvas { ctx, size in
                var r = SeededRNG(99)
                for _ in 0..<160 {
                    let p = CGPoint(x: r.next() * size.width, y: r.next() * size.height * 0.75)
                    let s = 0.8 + r.next() * 2.4
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x, y: p.y, width: s, height: s)), with: .color(.white.opacity(0.35 + Double(r.next()) * 0.6)))
                }
            }
            // 後光
            ZStack {
                ForEach(0..<14, id: \.self) { i in
                    Capsule().fill(LinearGradient(colors: [Color(red: 1, green: 0.9, blue: 0.5).opacity(0.55), .clear], startPoint: .bottom, endPoint: .top))
                        .frame(width: 34, height: 380).offset(y: -190).rotationEffect(.degrees(Double(i) / 14 * 360))
                }
            }
            .rotationEffect(.degrees(anim ? 360 : 0))
            .animation(.linear(duration: 60).repeatForever(autoreverses: false), value: anim)
            .position(x: W / 2, y: 360)
            Circle().fill(RadialGradient(colors: [Color(red: 1, green: 0.95, blue: 0.7), Color(red: 1, green: 0.7, blue: 0.3).opacity(0.5), .clear], center: .center, startRadius: 10, endRadius: 230))
                .frame(width: 460, height: 460).position(x: W / 2, y: 360)
            temple.position(x: W / 2, y: 390)
            // 遠くに浮かぶ島々
            ForEach(0..<5, id: \.self) { i in
                let x = [0.12, 0.88, 0.2, 0.82, 0.5][i] * W, y: CGFloat = [520, 560, 690, 720, 120][i]
                island(scale: [0.9, 0.8, 0.6, 0.65, 0.4][i])
                    .position(x: x, y: y + (anim ? -6 : 6))
                    .animation(.easeInOut(duration: 2.5 + Double(i) * 0.4).repeatForever(autoreverses: true), value: anim)
            }
            // 雲海
            ForEach(0..<9, id: \.self) { i in
                Ellipse().fill(.white.opacity(0.9 - Double(i % 3) * 0.12))
                    .frame(width: 220, height: 90)
                    .position(x: CGFloat(i) / 8 * W + (anim ? 10 : -10), y: H - 170 + CGFloat(i % 3) * 40)
                    .animation(.easeInOut(duration: 4 + Double(i % 3)).repeatForever(autoreverses: true), value: anim)
                    .blur(radius: 2)
            }
            // 雲の中へ消えていく光の道（ここから先はまだ見えない）
            Path { p in
                p.move(to: CGPoint(x: W / 2, y: H)); p.addCurve(to: CGPoint(x: W / 2, y: 520), control1: CGPoint(x: W * 0.15, y: H - 220), control2: CGPoint(x: W * 0.85, y: 700))
            }
            .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, dash: [2, 22]))
            .foregroundStyle(Color(red: 1, green: 0.95, blue: 0.6).opacity(0.9))
            .shadow(color: .yellow, radius: 6)
            VStack(spacing: 4) {
                Text("FINAL GOAL").font(DS.font(16, .black)).foregroundStyle(DS.gold).tracking(4)
                Text("伝説のDNA神殿").font(DS.font(34, .black)).foregroundStyle(.white)
                    .shadow(color: .purple, radius: 10)
                Text("最強の王 〈ジェネシス〉 が待つ").font(DS.font(14, .bold)).foregroundStyle(.white.opacity(0.85))
                Text(remaining > 0 ? "ゴールまで あと \(remaining) ステージ" : "ゴール到達！").font(DS.font(15, .black)).foregroundStyle(DS.navy)
                    .padding(.horizontal, 14).padding(.vertical, 4).background(DS.gold, in: Capsule()).padding(.top, 6)
            }.padding(.top, 175)
        }
        .frame(width: W, height: H).clipped()
        .allowsHitTesting(false)
    }

    private var temple: some View {
        let gold = LinearGradient(colors: [Color(red: 1, green: 0.95, blue: 0.65), Color(red: 0.85, green: 0.55, blue: 0.15)], startPoint: .top, endPoint: .bottom)
        return VStack(spacing: 0) {
            Image(systemName: "crown.fill").font(.system(size: 46, weight: .black)).foregroundStyle(gold).shadow(color: .yellow, radius: 12)
            Triangle().fill(gold).frame(width: 230, height: 70)
            Rectangle().fill(Color(red: 0.95, green: 0.8, blue: 0.4)).frame(width: 240, height: 12)
            HStack(spacing: 18) {
                ForEach(0..<6, id: \.self) { _ in
                    Rectangle().fill(LinearGradient(colors: [.white, Color(red: 0.9, green: 0.8, blue: 0.95)], startPoint: .leading, endPoint: .trailing)).frame(width: 16, height: 110)
                }
            }
            .overlay { Image(systemName: "questionmark").font(.system(size: 40, weight: .black)).foregroundStyle(.white.opacity(0.9)).shadow(color: .purple, radius: 8)
                .frame(width: 60, height: 90).background(Color(red: 0.25, green: 0.05, blue: 0.4), in: UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30)) }
            Rectangle().fill(Color(red: 0.95, green: 0.8, blue: 0.4)).frame(width: 260, height: 14)
            Rectangle().fill(Color(red: 0.8, green: 0.6, blue: 0.3)).frame(width: 290, height: 14)
        }
        .shadow(color: Color(red: 1, green: 0.8, blue: 0.3).opacity(0.8), radius: 20)
    }

    private func island(scale s: CGFloat) -> some View {
        VStack(spacing: -6) {
            Ellipse().fill(Color(red: 0.4, green: 0.85, blue: 0.5)).frame(width: 110 * s, height: 28 * s)
            Triangle().fill(LinearGradient(colors: [Color(red: 0.55, green: 0.4, blue: 0.5), Color(red: 0.25, green: 0.15, blue: 0.3)], startPoint: .top, endPoint: .bottom))
                .frame(width: 100 * s, height: 80 * s).rotationEffect(.degrees(180))
        }.opacity(0.85)
    }
}
