//
//  arata_original_appApp.swift
//  arata_original_app
//
//  Created by Arata Shimizu on 2026/07/12.
//

import SwiftUI

@main
struct arata_original_appApp: App {
    // 予定とタスクをアプリ全体で共有し、ディスクに保存するストア
    @State private var store = AppStore()
    // どの画面のSlackerボタンから開いても、同じ会話を表示する。
    @State private var slackerConversation = SlackerConversationStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(slackerConversation)
                .environment(\.locale, .app)
        }
    }
}
