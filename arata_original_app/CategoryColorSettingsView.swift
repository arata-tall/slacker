import SwiftUI

/// カテゴリごとの色をユーザーが変更する画面
struct CategoryColorSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    private var theme = ThemeSettings.shared

    @State private var showResetAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(EventCategory.allCases) { category in
                        ColorPicker(selection: binding(for: category), supportsOpacity: false) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.title)
                                Text(category.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("予定・タスクの色")
                } footer: {
                    Text("ここで決めた色が、カレンダー・今日の予定・タスクのすべてに反映されます。カレンダーの日付のまわりの輪も、その日の予定の内訳をこの色で表します。")
                }

                Section {
                    preview
                } header: {
                    Text("プレビュー")
                }

                if theme.isCustomized {
                    Section {
                        Button("初期設定の色に戻す", role: .destructive) {
                            showResetAlert = true
                        }
                    }
                }
            }
            .navigationTitle("色の設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .alert("初期設定に戻す", isPresented: $showResetAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("戻す", role: .destructive) {
                    theme.resetToDefaults()
                }
            } message: {
                Text("課題は赤、遊びは青、基本予定は黄に戻します。")
            }
            .liquidGlassForm()
        }
    }

    /// 日付のまわりの輪が、どう見えるかの確認用
    private var preview: some View {
        HStack(spacing: 20) {
            DayCategoryRing(segments: [
                CategorySegment(category: .assignment, fraction: 0.5),
                CategorySegment(category: .leisure, fraction: 0.2),
                CategorySegment(category: .routine, fraction: 0.3)
            ])
            .frame(width: 36, height: 36)
            .overlay(Text("30").font(.system(size: 16)))

            VStack(alignment: .leading, spacing: 4) {
                ForEach(EventCategory.allCases) { category in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(category.color)
                            .frame(width: 4, height: 16)
                        Text(category.title)
                            .font(.footnote)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func binding(for category: EventCategory) -> Binding<Color> {
        Binding(
            get: { theme.color(for: category) },
            set: { theme.setColor($0, for: category) }
        )
    }
}

#Preview {
    CategoryColorSettingsView()
}
