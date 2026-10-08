//
//  SyncUIApp.swift
//  SyncUI
//
//  Created by hara ryuto   on 2026/06/08.
//

import SwiftUI

@main
struct SyncUIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // タイトルバーをコンテンツと一体化し，没入感のある広いウィンドウにする
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1200, height: 820)
    }
}
