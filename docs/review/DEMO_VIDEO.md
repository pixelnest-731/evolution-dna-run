# デモ動画 撮影手順と台本

## 撮影（シミュレーター、Releaseビルド）
```
S=938A0A6B-9BF5-49CD-9ACD-AD1242FA2664
xcodebuild -project EvolutionDNARun.xcodeproj -scheme EvolutionDNARun -configuration Release -destination "id=$S" -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
xcrun simctl install $S build/Build/Products/Release-iphonesimulator/EvolutionDNARun.app
xcrun simctl io $S recordVideo --codec=h264 -f docs/review/demo.mp4   # Ctrl+C で終了
```
実機で撮る場合はコントロールセンターの画面収録を使用。長さは2〜3分。

## 台本
1. (0:00) 起動 → ホーム画面（タイトル・ボタン群）
2. (0:10) PLAY → ワールドマップ → ステージ1をタップ
3. (0:20) 左右スワイプでゲート通過、仲間が増える・属性が変わる様子
4. (0:50) ボス戦 → 弱点ヒット → BOSS CLEAR → 報酬
5. (1:20) 宝箱を開ける（排出率表示を映す）
6. (1:40) ショップ → 価格表示 → 「購入を復元」をタップ
7. (2:00) 設定 → プライバシーポリシー・利用規約リンク、進行状況リセット
8. (2:20) 終了

## 録画済み
- docs/review/demo_launch.mp4（起動〜ホーム、約10秒。Releaseビルド。容量が大きいためgit管理外）
