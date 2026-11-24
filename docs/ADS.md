# 広告設計（Google AdMob）

現状は `AdService`（EvolutionDNARun/UI/MetaViews.swift）が「テスト広告」画面を表示するだけ。SDKを入れたら中身だけ差し替える。

## 見せどころ（報酬型＝自分から見たくなる）
| 場所 | 報酬 | ねらい |
|---|---|---|
| ゲームオーバー | その場で復活（ボス戦なら残りHPから攻撃力2倍） | ニアミス表示「あと8%！」で一番押される |
| ゲームオーバー | 仲間3倍でリトライ | 負け続けの救済 |
| クリア | 報酬DNA 3倍 | 強化・宝箱に直結 |
| ログボ | 2倍受け取り | 毎日1回 |
| デイリーミッション | 報酬2倍 | 毎日3回 |
| 宝箱 | 無料待ち中にもう1個 | 10回に1回レア確定（天井）で回したくなる |

## インタースティシャル（強制）
- ステージ6以降、新規クリア3回ごと、前回から90秒以上空ける。NEXT押下時のみ（プレイ中は出さない）。
- 復活は1日10回まで。

## 本番化の手順（オーナー承認が必要）
1. AdMobでアプリ登録 → App ID・広告ユニットID（報酬型/インタースティシャル）発行
2. SPMで `https://github.com/googleads/swift-package-manager-google-mobile-ads` 追加
3. Info.plist に `GADApplicationIdentifier`、`SKAdNetworkItems`、ATT文言
4. UMP（同意管理）とATT許可ダイアログ
5. `AdService.showRewarded/showInterstitial` を RewardedAd / InterstitialAd に置換（開発中は Google のテストIDを使う）
6. 将来: 「広告削除」課金（StoreKit 2）でインタースティシャルを止める
