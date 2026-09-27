import SwiftUI

/// 月表示のカレンダーと、選択した日の予定一覧。
/// 予定は今日の予定画面と同じ AppStore を参照するため、どちらで追加しても両方に反映される。
struct CalendarView: View {
    @Environment(AppStore.self) private var store

    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date = Date()

    @State private var showAddSheet = false
    @State private var editingEvent: Event?
    @State private var showColorSettings = false
    @State private var showRoutines = false
    @State private var editingRoutine: RoutineSchedule?
    /// 左右スワイプで月を送るときの指の移動量
    @State private var monthDragOffset: CGFloat = 0

    private let calendar = Calendar.current
    private let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]

    private var selectedDayEvents: [Event] {
        store.events(on: selectedDate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    monthHeader
                    weekdayHeader
                    monthGrid
                }
                // 上部を左右にスワイプすると月を送る
                .contentShape(Rectangle())
                .offset(x: monthDragOffset)
                .gesture(monthSwipe)

                Divider()

                eventList
            }
            .navigationTitle("カレンダー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showRoutines = true
                    } label: {
                        Image(systemName: "repeat")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .accessibilityLabel("習慣・固定予定")

                    Button {
                        showColorSettings = true
                    } label: {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .accessibilityLabel("色の設定")

                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                    }
                    .accessibilityLabel("予定を追加")
                }
            }
            .sheet(isPresented: $showColorSettings) {
                CategoryColorSettingsView()
            }
            .sheet(isPresented: $showRoutines) {
                RoutineListView()
            }
            .sheet(item: $editingRoutine) { routine in
                RoutineFormView(routine: routine, navigationTitle: "習慣を編集") { saved in
                    store.update(saved)
                } onDelete: {
                    store.delete(routine)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddEventOrTaskSheet(event: newEvent()) { event in
                    store.add(event)
                } onAddTask: { task in
                    store.add(task)
                }
            }
            .sheet(item: $editingEvent) { event in
                EventFormView(event: event, navigationTitle: "予定の変更") { updated in
                    store.update(updated)
                } onDelete: {
                    store.delete(event)
                }
            }
            .liquidGlassScreen()
            .overlay(alignment: .bottomTrailing) {
                SlackerFloatingButton(tab: 0)
                    .padding(.trailing, 4)
                    .padding(.bottom, 10)
            }
        }
    }

    // MARK: - 月切替ヘッダー

    private var monthHeader: some View {
        HStack {
            Text(currentMonth.formatted(.dateTime.year().month().locale(.app)))
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            HStack(spacing: 20) {
                Button { changeMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                }
                .accessibilityLabel("前の月")

                Button { changeMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                }
                .accessibilityLabel("次の月")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                Text(symbol)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(index == 0 ? Color.red : (index == 6 ? Color.blue : Color.secondary))
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - 日付グリッド

    private var monthGrid: some View {
        let days = generateDaysInMonth(for: currentMonth)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, dayDate in
                if let dayDate {
                    dayCell(for: dayDate)
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private func dayCell(for dayDate: Date) -> some View {
        let isSelected = calendar.isDate(dayDate, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(dayDate)

        return Button {
            selectedDate = dayDate
        } label: {
            Text("\(calendar.component(.day, from: dayDate))")
                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(isSelected ? Color.accentColor
                                             : (isToday ? Color.gray.opacity(0.15) : Color.clear))
                )
                .foregroundStyle(isSelected ? Color.white : (isToday ? Color.accentColor : Color.primary))
                // その日の予定の内訳を輪で示す
                .overlay(DayCategoryRing(segments: segments(for: dayDate)))
        }
    }

    /// その日の予定を、種類ごとの時間の割合に直す
    private func segments(for day: Date) -> [CategorySegment] {
        let events = store.events(on: day)
        guard !events.isEmpty else { return [] }

        var minutesByCategory: [EventCategory: Double] = [:]
        for event in events where countsInRatio(event) {
            minutesByCategory[event.category, default: 0] += event.minutes(on: day)
        }

        let total = minutesByCategory.values.reduce(0, +)
        guard total > 0 else { return [] }

        // 常に同じ順序で描くことで、日によって並びが変わらないようにする
        return EventCategory.allCases.compactMap { category in
            guard let minutes = minutesByCategory[category], minutes > 0 else { return nil }
            return CategorySegment(category: category, fraction: minutes / total)
        }
    }

    /// 睡眠のように「比率に含めない」設定の習慣は、日付の輪から除く
    private func countsInRatio(_ event: Event) -> Bool {
        guard let routineID = event.routineID,
              let routine = store.routine(id: routineID) else { return true }
        return routine.countsInRatio
    }

    /// 左右スワイプで前後の月へ
    private var monthSwipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                // 指の動きに少しだけ追従させて、操作が効いていることを示す
                monthDragOffset = value.translation.width / 4
            }
            .onEnded { value in
                let threshold: CGFloat = 50
                if value.translation.width < -threshold {
                    changeMonth(by: 1)
                } else if value.translation.width > threshold {
                    changeMonth(by: -1)
                }
                withAnimation(.spring(duration: 0.25)) {
                    monthDragOffset = 0
                }
            }
    }

    // MARK: - 選択日の予定一覧

    private var eventList: some View {
        List {
            if selectedDayEvents.isEmpty {
                Text("予定はありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(selectedDayEvents) { event in
                    Button {
                        open(event)
                    } label: {
                        eventRow(event)
                    }
                    .swipeActions {
                        // 習慣から作られた予定は 1 回分だけ消せないため、削除は単発の予定のみ
                        if !event.isFromRoutine {
                            Button("削除", role: .destructive) {
                                store.delete(event)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    /// 習慣由来なら習慣の編集、単発なら予定の編集を開く
    private func open(_ event: Event) {
        if let routineID = event.routineID, let routine = store.routine(id: routineID) {
            editingRoutine = routine
        } else {
            editingEvent = event
        }
    }

    private func eventRow(_ event: Event) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.color)
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    if event.isFromRoutine {
                        Image(systemName: "repeat")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                if !event.location.isEmpty {
                    Label(event.location, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(event.timeRangeText)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .liquidGlassCard(cornerRadius: 14)
    }

    // MARK: - ロジック

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentMonth = newMonth
        }
    }

    /// その月の日付を返す。月初の曜日ぶんだけ先頭に nil を詰める。
    private func generateDaysInMonth(for date: Date) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return []
        }

        let leadingBlanks = calendar.component(.weekday, from: firstOfMonth) - 1
        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)

        for day in 0..<range.count {
            days.append(calendar.date(byAdding: .day, value: day, to: firstOfMonth))
        }
        return days
    }

    /// 選択中の日付の、現在時刻から 1 時間の予定を初期値にする
    private func newEvent() -> Event {
        let now = Date()
        let start = calendar.date(bySettingHour: calendar.component(.hour, from: now),
                                  minute: calendar.component(.minute, from: now),
                                  second: 0,
                                  of: selectedDate) ?? selectedDate

        return Event(title: "",
                     start: start,
                     end: start.addingTimeInterval(3600),
                     category: .routine)
    }

}

/// 予定追加画面で、タスクとしても同時登録できる共通フォーム。
/// タスクをオンにすると、予定とタスクを同時に AppStore へ保存する。
struct AddEventOrTaskSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onAddEvent: (Event) -> Void
    let onAddTask: (TaskItem) -> Void

    /// オンの場合は、終了時刻を期限とするタスクも同時に作る。
    @State private var isTask = false
    @State private var eventDraft: Event

    init(event: Event,
         onAddEvent: @escaping (Event) -> Void,
         onAddTask: @escaping (TaskItem) -> Void) {
        _eventDraft = State(initialValue: event)
        self.onAddEvent = onAddEvent
        self.onAddTask = onAddTask
    }

    private var isValid: Bool {
        !eventDraft.title.trimmingCharacters(in: .whitespaces).isEmpty
            && eventDraft.end >= eventDraft.start
    }

    var body: some View {
        NavigationStack {
            Form {
                entryFields
            }
            .navigationTitle("追加")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: eventDraft.start) { oldValue, newValue in
                if eventDraft.end < newValue {
                    eventDraft.end = newValue.addingTimeInterval(eventDraft.end.timeIntervalSince(oldValue))
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加", action: save)
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .liquidGlassForm()
        }
        .presentationDetents([.large])
    }

    private var entryFields: some View {
        Group {
            Section(isTask ? "タスクの内容" : "予定の内容") {
                TextField("タイトル", text: $eventDraft.title)
                TextField("場所", text: $eventDraft.location)
            }

            Section("時間の設定") {
                Toggle(isOn: $eventDraft.isAllDay.animation()) {
                    Label("終日", systemImage: "clock")
                }

                // 終日と同じ位置で切り替え、オンなら終了時刻だけをタスクの期限に使う。
                Toggle(isOn: $isTask.animation()) {
                    Label("タスク", systemImage: "checklist")
                }

                // タスクでも開始時刻は入力・確認できるよう表示を維持する。
                DatePicker("開始", selection: $eventDraft.start,
                           displayedComponents: eventDraft.isAllDay ? [.date] : [.date, .hourAndMinute])
                DatePicker("終了", selection: $eventDraft.end,
                           displayedComponents: eventDraft.isAllDay ? [.date] : [.date, .hourAndMinute])
            }

            CategorySection(selection: $eventDraft.category)
        }
    }

    private func save() {
        if isTask {
            // タスクとして作った内容も予定として残し、カレンダーとタスク一覧を同期させる。
            let savedEvent = normalized(eventDraft)
            onAddEvent(savedEvent)
            onAddTask(TaskItem(title: eventDraft.title.trimmingCharacters(in: .whitespaces),
                               dueDate: savedEvent.end,
                               category: eventDraft.category))
        } else {
            onAddEvent(normalized(eventDraft))
        }
        dismiss()
    }

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

#Preview {
    CalendarView()
        .environment(AppStore.preview)
        .environment(SlackerConversationStore())
        .environment(SlackerNavigationStore())
}
