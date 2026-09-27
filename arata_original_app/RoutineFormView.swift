import SwiftUI

/// 習慣（毎週の固定予定）の追加・編集フォーム
struct RoutineFormView: View {
    @Environment(\.dismiss) private var dismiss

    let navigationTitle: String
    let onSave: (RoutineSchedule) -> Void
    let onDelete: (() -> Void)?

    @State private var draft: RoutineSchedule
    @State private var hasEndDate: Bool
    @State private var showDeleteAlert = false

    init(routine: RoutineSchedule,
         navigationTitle: String,
         onSave: @escaping (RoutineSchedule) -> Void,
         onDelete: (() -> Void)? = nil) {
        _draft = State(initialValue: routine)
        _hasEndDate = State(initialValue: routine.endDate != nil)
        self.navigationTitle = navigationTitle
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var isValid: Bool {
        !draft.title.trimmingCharacters(in: .whitespaces).isEmpty && !draft.weekdays.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("内容")) {
                    TextField("名前（例: 数学、睡眠、ピアノ）", text: $draft.title)
                    TextField("場所", text: $draft.location)
                }

                Section {
                    weekdayPicker
                    quickWeekdayButtons
                } header: {
                    Text("繰り返す曜日")
                } footer: {
                    Text(draft.weekdays.isEmpty
                         ? "曜日を1つ以上選んでください。"
                         : "\(draft.weekdaysText) に繰り返します。")
                }

                Section {
                    timePicker("開始", hour: $draft.startHour, minute: $draft.startMinute)
                    timePicker("終了", hour: $draft.endHour, minute: $draft.endMinute)
                } header: {
                    Text("時間")
                } footer: {
                    Text(draft.crossesMidnight
                         ? "終了が開始より前なので、翌日の \(String(format: "%02d:%02d", draft.endHour, draft.endMinute)) まで続く扱いになります（睡眠など）。"
                         : "毎回 \(draft.timeRangeText) の予定になります。")
                }

                CategorySection(selection: $draft.category)

                Section {
                    DatePicker("開始日", selection: $draft.startDate, displayedComponents: .date)

                    Toggle("終了日を決める", isOn: $hasEndDate.animation())
                    if hasEndDate {
                        DatePicker("終了日",
                                   selection: Binding(get: { draft.endDate ?? draft.startDate },
                                                      set: { draft.endDate = $0 }),
                                   in: draft.startDate...,
                                   displayedComponents: .date)
                    }

                    Toggle("有効にする", isOn: $draft.isEnabled)
                } header: {
                    Text("期間")
                } footer: {
                    Text("学期の終わりが決まっている場合などに終了日を設定します。一時的に休むときは「有効にする」をオフにしてください。")
                }

                Section {
                    Toggle("カレンダーの色の比率に含める",
                           isOn: Binding(get: { draft.countsInRatio },
                                         set: { draft.countsInDayRatio = $0 }))
                } footer: {
                    Text("睡眠のように毎日必ずある予定は、含めるとどの日も同じ色になってしまいます。オフにすると予定としては残りますが、日付のまわりの輪には出ません。")
                }

                if onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("この習慣を削除", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: hasEndDate) { _, newValue in
                if !newValue { draft.endDate = nil }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .alert("習慣を削除", isPresented: $showDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("この習慣から作られる予定が、カレンダーからすべて消えます。")
            }
            .liquidGlassForm()
        }
    }

    // MARK: - パーツ

    /// 曜日を丸ボタンで複数選ぶ
    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { weekday in
                let isOn = draft.weekdays.contains(weekday)

                Button {
                    if isOn {
                        draft.weekdays.remove(weekday)
                    } else {
                        draft.weekdays.insert(weekday)
                    }
                } label: {
                    Text(RoutineSchedule.symbol(for: weekday))
                        .font(.subheadline)
                        .fontWeight(isOn ? .bold : .regular)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(isOn ? draft.category.color : Color(uiColor: .tertiarySystemFill),
                                    in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var quickWeekdayButtons: some View {
        HStack(spacing: 8) {
            quickButton("平日", weekdays: RoutineSchedule.weekdays平日)
            quickButton("土日", weekdays: RoutineSchedule.weekdays週末)
            quickButton("毎日", weekdays: RoutineSchedule.weekdays毎日)

            Spacer()

            Button("クリア") { draft.weekdays = [] }
                .font(.footnote)
                .disabled(draft.weekdays.isEmpty)
        }
    }

    private func quickButton(_ title: String, weekdays: Set<Int>) -> some View {
        Button(title) { draft.weekdays = weekdays }
            .font(.footnote)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
    }

    /// 時刻をドラムロール（ホイール）で設定する（1分刻み）
    private func timePicker(_ title: String, hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack {
            Text(title)

            Spacer()

            HStack(spacing: 0) {
                Picker("時", selection: hour) {
                    ForEach(0..<24, id: \.self) {
                        Text(String(format: "%02d", $0)).tag($0)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60, height: 100)
                .clipped()

                Text(":")
                    .font(.headline)

                Picker("分", selection: minute) {
                    ForEach(0..<60, id: \.self) {
                        Text(String(format: "%02d", $0)).tag($0)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60, height: 100)
                .clipped()
            }
        }
    }
}

#Preview {
    RoutineFormView(routine: RoutineSchedule(title: "数学", weekdays: [2, 4],
                                             startHour: 9, startMinute: 0,
                                             endHour: 10, endMinute: 30),
                    navigationTitle: "習慣を追加",
                    onSave: { _ in })
}
