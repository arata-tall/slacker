import SwiftUI

/// 削除済みタスクの一覧（ゴミ箱）。
/// 誤って削除しても、ここから元に戻せる。
struct DeletedTaskView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showEmptyTrashAlert = false

    private var deletedTasks: [TaskItem] { store.deletedTasks }

    var body: some View {
        NavigationStack {
            List {
                ForEach(deletedTasks) { task in
                    row(for: task)
                        .listRowBackground(Color.clear)
                }
            }
            .overlay {
                if deletedTasks.isEmpty {
                    ContentUnavailableView("削除済みのタスクはありません",
                                           systemImage: "trash",
                                           description: Text("削除したタスクはここに移動し、元に戻せます"))
                }
            }
            .navigationTitle("削除済みタスク")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    // タイトルを圧迫しないよう短い文言にする（確認アラートで内容を説明する）
                    Button("空にする", role: .destructive) {
                        showEmptyTrashAlert = true
                    }
                    .disabled(deletedTasks.isEmpty)
                }
            }
            .alert("ゴミ箱を空にする", isPresented: $showEmptyTrashAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("完全に削除", role: .destructive) {
                    withAnimation { store.emptyTrash() }
                }
            } message: {
                Text("\(deletedTasks.count)件のタスクを完全に削除します。この操作は元に戻せません。")
            }
            .liquidGlassForm()
        }
    }

    private func row(for task: TaskItem) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // タップで一覧に戻す
            Button {
                withAnimation { store.restore(task) }
            } label: {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("元に戻す")

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)

                Text("期限: \(task.dueDateText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let deletedAtText = task.deletedAtText {
                    Text("削除: \(deletedAtText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .liquidGlassCard(cornerRadius: 14)
        .swipeActions(edge: .trailing) {
            Button("完全に削除", role: .destructive) {
                withAnimation { store.permanentlyDelete(task) }
            }
        }
        .swipeActions(edge: .leading) {
            Button("元に戻す") {
                withAnimation { store.restore(task) }
            }
            .tint(.blue)
        }
    }
}

#Preview {
    DeletedTaskView()
        .environment(AppStore.preview)
}
