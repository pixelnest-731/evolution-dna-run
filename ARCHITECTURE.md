# アーキテクチャ（AI社員01/02）
## 技術選定
| 候補 | 判断 |
|---|---|
| SceneKit + SwiftUI | **採用**。追加費用なし、Xcode単体で完結、AdMob/StoreKit連携が容易、プロシージャル生成と相性良 |
| RealityKit | AR寄りでカスタムシェーダー/ランナー向けカメラ制御が煩雑 → 不採用 |
| Unity | 品質は高いがこのMacに未インストール、ライセンス要件あり → オーナー承認案件のため保留 |
| Metal直書き | 開発コスト過大。SceneKitのshaderModifierで部分的に利用 |
## 構成
- Model/GameModel.swift: 属性・ゲート・Swarm（論理）・SplitMix64・StageGenerator・Solver
- Model/Progress.swift: セーブ（JSON, version付き）・図鑑名
- Render/: CreatureFactory（プロシージャル生命体/ボス/障害物）, WorldBuilder（背景・ゲート・FX）
- Game/GameController.swift: CADisplayLinkループ、描画上限70体（巨大個体は12体）、カメラ、ボス戦
- Audio/AudioEngine.swift: AVAudioEngine、SFX 12ボイスプール、BGM 3ステムのダイナミックミックス、Core Haptics
- UI/App.swift: SwiftUI 画面群
