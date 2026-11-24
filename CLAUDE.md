# Evolution DNA Run — 作業ルール
- 再開時は必ず PROGRESS.md → TASKS.md を読む。AI社員定義は .claude/agents/、役割は AGENT_ROLES.md。
- エンジン: Swift + SceneKit + SwiftUI（iOS 17+）。プロジェクトは EvolutionDNARun.xcodeproj（同期フォルダ方式、ファイル追加でpbxproj編集不要）。
- ビルド: xcodebuild -project EvolutionDNARun.xcodeproj -scheme EvolutionDNARun -destination 'id=<sim>' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
- 音源再生成: python3 tools/synth_audio.py（標準ライブラリのみ）
- 論理生物数と描画数を分離すること（描画上限 GameController.maxVisible）。
- 本番広告ID・課金設定・外部登録・App Store提出はオーナー承認必須。
