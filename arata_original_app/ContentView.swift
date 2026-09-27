import SwiftUI
import Observation

/// Slackerを開いたタブを記録し、別タブへ移動したときに自動で閉じる。
@Observable
final class SlackerNavigationStore {
    var originTab: Int?
}

struct ContentView: View {
    // 現在選択されているタブを管理する状態変数
    @State private var selectedTab = 0
    @State private var slackerNavigation = SlackerNavigationStore()

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarView()
                .tabItem {
                    Label("カレンダー", systemImage: "calendar")
                }
                .tag(0)

            TodayView()
                .tabItem {
                    Label("今日の予定", systemImage: "clock")
                }
                .tag(1)

            TaskView()
                .tabItem {
                    Label("タスク", systemImage: "checklist")
                }
                .tag(2)
        }
        .environment(slackerNavigation)
        // 別のタブを選んだら、元のタブに積まれたSlacker画面を閉じる。
        .onChange(of: selectedTab) { _, _ in
            slackerNavigation.originTab = nil
        }
        .liquidGlassScreen()
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

#Preview {
    ContentView()
        .environment(AppStore.preview)
        .environment(SlackerConversationStore())
}
