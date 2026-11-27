# App Review Notes（下書き）

## English (paste into App Store Connect > App Review Information > Notes)
Evolution DNA Run is an offline, single-player casual runner game. No account or login is required.

**How to play:** Tap PLAY, choose a stage on the world map, and swipe left/right to steer your creature swarm through gates. Gates add/multiply creatures or change their element (fire/ice/thunder). At the end of a stage you fight a boss; hitting its elemental weakness deals 2x damage. Mini-bosses appear during longer stages.

**In-App Purchases:** All digital goods are sold only via Apple IAP (StoreKit 2). Prices are loaded from the App Store. "Restore Purchases" is available in Shop and in Settings > Data.
- Non-consumable: Starter Pack (one time), Remove Ads
- Consumable: DNA packs (500/1,800/4,500/12,000), Gold Character Box (guaranteed gold character, not random)

**Random rewards:** The Treasure Chest (opened for free every few hours or with in-game DNA) shows its drop rates on screen: Gold character 8% / upgrade 17% / DNA 75%, with a guaranteed gold character every 10th chest.

**Ads:** This build contains no third-party ad SDK and no tracking. (If ads are added later, ATT will be requested before any tracking.)

**Privacy:** No personal data is collected; progress is stored on-device only. Progress can be deleted from Settings > Data > Reset.

**Demo:** A screen recording is attached / available on request. Steps: Launch > PLAY > Stage 1 > swipe through gates > boss battle > result screen > Shop > Restore Purchases.

## 日本語訳
Evolution DNA Run はオフラインの1人用カジュアルランゲームです。アカウント・ログイン不要。
- 遊び方: PLAY → ワールドマップでステージ選択 → 左右スワイプで群れを操作しゲートを通過。ゲートで仲間が増減・属性（炎/氷/雷）が変化。最後にボス戦、弱点属性で2倍ダメージ。長いステージでは小ボスも出現。
- 課金: デジタル商品はすべて Apple IAP（StoreKit 2）のみ。価格は App Store から取得。「購入を復元」はショップと設定＞データにあり。非消耗型: スターターパック・広告削除。消耗型: DNAパック4種、金色キャラ確定ボックス（確定なのでランダムではない）。
- ランダム報酬: 宝箱（数時間ごとに無料 or ゲーム内DNA）は排出率を画面に表示（金色キャラ8%／強化17%／DNA75%、10回目ごとに金色確定）。
- 広告: 本ビルドは第三者広告SDK・トラッキングなし（導入時は ATT 許可を先に求める）。
- プライバシー: 個人情報は収集せず、進行は端末内のみ。設定＞データ＞リセットで削除可能。
- デモ: 起動 → PLAY → ステージ1 → ゲート通過 → ボス戦 → リザルト → ショップ → 購入を復元。

> 注: AdMob 接続後は Ads 段落と PrivacyInfo.xcprivacy・プライバシーポリシーを更新すること。
