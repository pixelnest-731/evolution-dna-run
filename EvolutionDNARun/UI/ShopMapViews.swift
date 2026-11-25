import SwiftUI

// MARK: - ショップ
struct ShopView: View {
    @ObservedObject var shop = Shop.shared
    @ObservedObject var progress = Progress.shared
    @State private var note: String?
    var body: some View {
        SheetFrame(title: "ショップ") {
            HStack(spacing: 12) {
                Label("\(shop.s.reviveTickets)", systemImage: "heart.fill").foregroundStyle(.pink)
                Label("\(shop.s.startTickets)", systemImage: "person.3.fill").foregroundStyle(.cyan)
                if shop.s.noAds { Label("広告なし", systemImage: "nosign").foregroundStyle(.green) }
            }.font(DS.font(15, .bold)).frame(maxWidth: .infinity, alignment: .leading)

            guide
            header("💎 DNAで買う")
            ForEach(DNAItem.all) { i in
                row(icon: i.icon, color: i.id == "unique" ? .yellow : .pink, title: i.title, detail: i.detail, use: i.use, tag: i.id == "unique" ? "ユニーク" : nil) {
                    if shop.ownedDNA(i) { Text("入手済み").font(DS.font(14, .bold)).foregroundStyle(.white.opacity(0.7)).frame(width: 96) } else {
                    Button {
                        if shop.buy(i) { AudioEngine.shared.play("gate_big"); Haptics.shared.tap(0.8) } else { note = "DNAが足りません" }
                    } label: { Text("💎 \(i.cost)").font(DS.font(15, .black)).frame(width: 96, height: 40) }
                    .buttonStyle(GameButtonStyle(top: Color(red: 0.45, green: 0.7, blue: 1), bottom: DS.blue, radius: 20))
                    .opacity(progress.data.dna >= i.cost ? 1 : 0.5)
                    }
                }
            }

            header("🛒 スペシャル")
            ForEach(IAPItem.all) { i in
                row(icon: i.icon, color: i.consumable ? .orange : .purple, title: i.title, detail: i.detail, use: i.use, tag: i.tag) {
                    if shop.owned(i) {
                        Text("購入済み").font(DS.font(14, .bold)).foregroundStyle(.white.opacity(0.7)).frame(width: 96)
                    } else {
                        Button { Task { await shop.purchase(i) } } label: {
                            Text(shop.price(i)).font(DS.font(15, .black)).frame(width: 96, height: 40)
                        }.buttonStyle(GameButtonStyle(top: Color(red: 0.55, green: 0.98, blue: 0.3), bottom: Color(red: 0.15, green: 0.72, blue: 0.15), radius: 20))
                        .disabled(shop.busy)
                    }
                }
            }
            Button("購入を復元") { Task { await shop.restore() } }.font(DS.font(14, .bold)).foregroundStyle(.white.opacity(0.8))
            if !shop.available {
                Text("※ 課金アイテムは App Store 登録後に購入できるようになります（今は表示のみ）").font(.caption).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
            }
        }
        .overlay { if shop.busy { ProgressView().controlSize(.large).tint(.white) } }
        .alert("ショップ", isPresented: Binding(get: { (note ?? shop.message) != nil }, set: { if !$0 { note = nil; shop.message = nil } })) {
            Button("OK") {}
        } message: { Text(note ?? shop.message ?? "") }
    }
    private var guide: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("ショップのつかいかた").font(DS.font(15, .black)).foregroundStyle(DS.gold)
            Text("💎 DNA … ステージで集まるお金。「強化」で仲間を強くしたり、下のアイテムと交換できます").font(DS.font(12, .bold))
            Text("❤️ 復活チケット … 負けたとき、広告なしでその場から続けられます").font(DS.font(12, .bold))
            Text("👥 仲間2倍チケット … 次のステージを仲間2倍の状態でスタートできます").font(DS.font(12, .bold))
            Text("✨ 金色キャラ … レアな仲間。図鑑に登録されます").font(DS.font(12, .bold))
            Text("🤖 シークレット／🗡️ ユニーク … 図鑑で「相棒」にすると、そのキャラでステージに出発します").font(DS.font(12, .bold))
        }
        .foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12).background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
    }
    private func header(_ t: String) -> some View {
        Text(t).font(DS.font(18, .black)).foregroundStyle(DS.gold).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
    }
    private func row<B: View>(icon: String, color: Color, title: String, detail: String, use: String, tag: String?, @ViewBuilder button: () -> B) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                .frame(width: 54, height: 54).background(LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(DS.font(16, .black)).foregroundStyle(.white)
                    if let tag { Text(tag).font(DS.font(11, .black)).foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 2).background(Color.red, in: Capsule()) }
                }
                Text(detail).font(DS.font(12, .medium)).foregroundStyle(.white.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
                if !use.isEmpty {
                    Text("💡 " + use).font(DS.font(11, .bold)).foregroundStyle(Color(red: 0.6, green: 0.95, blue: 1)).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 4)
            button()
        }
        .padding(10).background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
    }
}

// MapView は MapViews.swift に移動（背景・装飾つきワールドマップ）
