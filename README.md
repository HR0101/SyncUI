# SyncUI (macOS / iOS)

SwiftUI コードとビジュアルキャンバスが双方向にリアルタイム同期する、インタラクティブな SwiftUI ビジュアルエディタです。

---

## ✨ 主な機能

- **双方向リアルタイム同期 (Two-way Realtime Sync)**
  - **Code to Canvas**: コードエディタで SwiftUI コードを編集すると、構文解析エンジンが即座にキャンバスのプレビューへ反映
  - **Inspector to Code**: インスペクタ UI（GUIスライダーやピッカー）で色やサイズ、パディングを変更すると、コード側の該当行が自動更新
- **SwiftUI 構文パーサー (`SwiftUICodeParser`)**
  - Text, Button, Image, Stack（VStack, HStack, ZStack）などの主要コンポーネントとそのモディファイアをAST/正規表現ベースで解析
- **3ペイン構成のモダンなエディタレイアウト**
  - 左: コンポーネントツリー / ソースエディタ (`CodeView`)
  - 中央: リアルタイムレンダリングキャンバス (`CanvasView`)
  - 右: プロパティインスペクタ (`InspectorView`)

---

## 🛠 技術構成

- **プラットフォーム**: macOS 13.0+ / iPadOS 16.0+
- **言語**: Swift
- **UIフレームワーク**: SwiftUI
- **アーキテクチャ**: MVVM (`EditorViewModel`)

---

## 📂 プロジェクト構成

```
SyncUI/
├── SyncUI/
│   ├── SyncUIApp.swift          # エントリポイント
│   ├── ContentView.swift        # メイン3ペインレイアウト
│   ├── CanvasView.swift         # プレビューレンダリング領域
│   ├── CodeView.swift           # シンタックス対応コードエディタ
│   ├── InspectorView.swift      # プロパティ編集GUI
│   ├── EditorViewModel.swift    # 双方向状態同期エンジン
│   ├── SwiftUICodeParser.swift  # SwiftUI 構文解析パーサー
│   └── Models.swift             # UI要素モデル定義
└── SyncUI.xcodeproj
```

---

## 🚀 使い方

1. Xcode で `SyncUI.xcodeproj` を開きます。
2. ターゲット（macOS または iPad）を選択してビルド・実行します。
3. エディタに SwiftUI コードを入力するか、キャンバス上で要素を選択して右側のインスペクタから見た目を調整します。
