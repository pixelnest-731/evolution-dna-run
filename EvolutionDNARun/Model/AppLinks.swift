import Foundation

/// 外部リンクとビルド種別で変わる値（審査ガイドライン 5.1.1 / 2.1）
enum AppLinks {
    /// プライバシーポリシーURL。公開ページ作成後にオーナーが設定する。原稿は docs/privacy.html（GitHub Pages を /docs で公開するとこのURLになる。公開前はリンク切れになるので要公開）
    static let privacyPolicy: URL? = URL(string: "https://pixelnest-731.github.io/evolution-dna-run/privacy.html")
    /// 利用規約URL（Apple標準EULAを使う場合はそのURL）
    static let terms: URL? = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")

    /// ストア未接続時の案内。開発用の「表示のみ」文言はリリースビルドに出さない
    static var storeUnavailableNote: String {
        #if DEBUG
        "※ 課金アイテムは App Store 登録後に購入できるようになります（今は表示のみ）"
        #else
        "ストアに接続できません。通信環境を確認して、しばらくしてからお試しください。"
        #endif
    }

    /// デバッグ用の任意ステージ起動（-debugStage N）。リリースビルドでは無効
    static var debugStage: Int {
        #if DEBUG
        UserDefaults.standard.integer(forKey: "debugStage")
        #else
        0
        #endif
    }
}
