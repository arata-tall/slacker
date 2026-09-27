import SwiftUI

struct TaskView: View {
    @Environment(AppStore.self) private var store

    @State private var isShowingAddSheet = false
    @State private var newTaskTitle = ""
    @State private var newTaskDate = Date()
    @State private var newTaskCategory: EventCategory = .assignment
    @State private var searchText = ""

    /// チェックを付けてから消えるまでの間だけ ID を保持する（保存はしない）
    @State private var completingTaskIDs: Set<UUID> = []
    @State private var isShowingTrash = false

    /// 期限の早い順に並べる
    private var visibleTasks: [TaskItem] {
        let matched = searchText.isEmpty
            ? store.activeTasks
            : store.activeTasks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }

        return matched.sorted { $0.dueDate < $1.dueDate }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleTasks) { task in
                    row(for: task)
                        .listRowBackground(Color.clear)
                }
                .onDelete(perform: deleteTasks)
            }
            .overlay {
                if visibleTasks.isEmpty {
                    if searchText.isEmpty {
                        ContentUnavailableView("タスクはありません",
                                               systemImage: "checklist",
                                               description: Text("右上の ＋ から追加できます。削除したタスクはゴミ箱から元に戻せます。"))
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
            .navigationTitle("タスク一覧")
            // 大きいタイトル用の領域を使わず、検索欄と一覧を上へ詰める。
            .navigationBarTitleDisplayMode(.inline)
            // 検索バー自体が虫眼鏡を備えているため、ツールバーの検索ボタンは廃止
            .searchable(text: $searchText, prompt: "タスクを検索")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        isShowingTrash = true
                    } label: {
                        // 件数はツールバーの枠内に収まるよう、アイコンの横に並べる
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            if !store.deletedTasks.isEmpty {
                                Text("\(store.deletedTasks.count)")
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                            }
                        }
                        .font(.title3)
                    }
                    .accessibilityLabel("削除済みタスク \(store.deletedTasks.count)件")

                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                            .bold()
                    }
                    .accessibilityLabel("タスクを追加")
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                addTaskSheet
            }
            .sheet(isPresented: $isShowingTrash) {
                DeletedTaskView()
            }
            .liquidGlassForm()
            .overlay(alignment: .bottomTrailing) {
                SlackerFloatingButton(tab: 2)
                    .padding(.trailing, 4)
                    .padding(.bottom, 10)
            }
        }
    }

    private func row(for task: TaskItem) -> some View {
        let isCompleting = completingTaskIDs.contains(task.id)

        return HStack(alignment: .top, spacing: 16) {
            // タップでチェックを付け、そのままゴミ箱へ移す（ゴミ箱から元に戻せる）
            Button {
                complete(task)
            } label: {
                Image(systemName: isCompleting ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.color)
            }
            .buttonStyle(.plain)
            .disabled(isCompleting)
            .accessibilityLabel("完了にして削除")

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(isCompleting)
                    .foregroundStyle(isCompleting ? .secondary : .primary)

                HStack(spacing: 6) {
                    Text("終了: \(task.dueTimeText)")

                    Text(task.category.title)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(task.color.opacity(0.2), in: Capsule())
                        .foregroundStyle(task.color)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .liquidGlassCard(cornerRadius: 14)
    }

    /// チェックが見えるように少しだけ待ってからゴミ箱へ移す
    private func complete(_ task: TaskItem) {
        guard !completingTaskIDs.contains(task.id) else { return }

        withAnimation {
            _ = completingTaskIDs.insert(task.id)
        }

        Task {
            try? await Task.sleep(for: .seconds(0.35))
            withAnimation {
                store.delete(task)
            }
            completingTaskIDs.remove(task.id)
        }
    }

    private var addTaskSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("タスク名を入力", text: $newTaskTitle)
                    DatePicker("期限", selection: $newTaskDate, displayedComponents: .date)
                }

                CategorySection(selection: $newTaskCategory)
            }
            .navigationTitle("新しいタスク")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismissAddSheet() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        store.add(TaskItem(title: newTaskTitle.trimmingCharacters(in: .whitespaces),
                                           dueDate: newTaskDate,
                                           category: newTaskCategory))
                        dismissAddSheet()
                    }
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .liquidGlassForm()
        }
        .presentationDetents([.large])
    }

    private func dismissAddSheet() {
        isShowingAddSheet = false
        newTaskTitle = ""
        newTaskDate = Date()
        newTaskCategory = .assignment
    }

    /// スワイプ削除（表示中のリストの位置から元のタスクを特定してゴミ箱へ移す）
    private func deleteTasks(at offsets: IndexSet) {
        // 削除するたびに visibleTasks が変化するため、先に対象を確定させておく
        let targets = offsets.map { visibleTasks[$0] }
        for task in targets {
            store.delete(task)
        }
    }
}

#Preview {
    TaskView()
        .environment(AppStore.preview)
        .environment(SlackerConversationStore())
        .environment(SlackerNavigationStore())
}
