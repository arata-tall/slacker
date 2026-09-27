import SwiftUI

/// 予定の追加・編集で共用するフォーム。
struct EventFormView: View {
    @Environment(\.dismiss) private var dismiss

    let navigationTitle: String
    let onSave: (Event) -> Void
    /// 編集時のみ渡す。nil の場合は削除ボタンを表示しない。
    let onDelete: (() -> Void)?

    @State private var draft: Event
    @State private var showDeleteAlert = false

    init(event: Event,
         navigationTitle: String,
         onSave: @escaping (Event) -> Void,
         onDelete: (() -> Void)? = nil) {
        _draft = State(initialValue: event)
        self.navigationTitle = navigationTitle
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var isValid: Bool {
        !draft.title.trimmingCharacters(in: .whitespaces).isEmpty && draft.end >= draft.start
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("予定の内容")) {
                    TextField("タイトル", text: $draft.title)
                    TextField("場所", text: $draft.location)
                }

                Section(header: Text("時間の設定")) {
                    Toggle(isOn: $draft.isAllDay.animation()) {
                        Label("終日", systemImage: "clock")
                    }

                    DatePicker("開始", selection: $draft.start,
                               displayedComponents: draft.isAllDay ? [.date] : [.date, .hourAndMinute])
                    DatePicker("終了", selection: $draft.end,
                               displayedComponents: draft.isAllDay ? [.date] : [.date, .hourAndMinute])

                    if draft.end < draft.start {
                        Label("終了は開始より後にしてください", systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                CategorySection(selection: $draft.category)

                if onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("予定を削除", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            // 開始を終了より後にずらしたら、長さを保ったまま終了も動かす
            .onChange(of: draft.start) { oldValue, newValue in
                if draft.end < newValue {
                    draft.end = newValue.addingTimeInterval(draft.end.timeIntervalSince(oldValue))
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(normalized(draft))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .alert("予定を削除", isPresented: $showDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("この予定を削除してもよろしいですか？")
            }
            .liquidGlassForm()
        }
    }

    /// 終日予定は 0:00〜23:59 に丸めて保存する
    private func normalized(_ event: Event) -> Event {
        guard event.isAllDay else { return event }

        var normalized = event
        let calendar = Calendar.current
        normalized.start = calendar.startOfDay(for: event.start)
        normalized.end = calendar.date(bySettingHour: 23, minute: 59, second: 0,
                                       of: calendar.startOfDay(for: event.end)) ?? event.end
        return normalized
    }
}

/// 予定・タスク共通のカテゴリ選択。色はカテゴリから自動で決まる。
struct CategorySection: View {
    @Binding var selection: EventCategory

    var body: some View {
        Section {
            ForEach(EventCategory.allCases) { category in
                Button {
                    selection = category
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(category.color)
                            .frame(width: 14, height: 14)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.title)
                                .foregroundStyle(.primary)
                            Text(category.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if selection == category {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .fontWeight(.bold)
                        }
                    }
                }
            }
        } header: {
            Text("種類")
        } footer: {
            Text("色は種類ごとに決まります。色そのものはカレンダー画面の設定から変更できます。")
        }
    }
}

#Preview {
    EventFormView(event: Event(title: "打ち合わせ", start: .now, end: .now.addingTimeInterval(3600)),
                  navigationTitle: "予定の追加",
                  onSave: { _ in })
}
