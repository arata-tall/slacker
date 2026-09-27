import SwiftUI

/// 今日の予定だけを表示する画面。データはカレンダー画面と同じ AppStore を参照する。
struct TodayView: View {
    @Environment(AppStore.self) private var store

    @State private var showAddSheet = false
    @State private var editingEvent: Event?
    @State private var editingRoutine: RoutineSchedule?

    private var today: Date { Date() }

    private var todaysEvents: [Event] {
        store.events(on: today)
    }

    private var dayString: String {
        "\(Calendar.current.component(.day, from: today))"
    }

    private var weekdayString: String {
        today.formatted(.dateTime.weekday(.abbreviated).locale(.app))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                HStack(alignment: .top, spacing: 16) {
                    // 現在の日付と連動するヘッダー表示
                    VStack(spacing: 4) {
                        Text(dayString)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.accentColor, in: Circle())

                        Text(weekdayString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)

                    VStack(spacing: 12) {
                        if todaysEvents.isEmpty {
                            Text("今日の予定はありません")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 24)
                        } else {
                            ForEach(todaysEvents) { event in
                                Button {
                                    if let routineID = event.routineID,
                                       let routine = store.routine(id: routineID) {
                                        editingRoutine = routine
                                    } else {
                                        editingEvent = event
                                    }
                                } label: {
                                    EventRowView(event: event)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            .liquidGlassScreen()
            .navigationTitle("今日のスケジュール")
            // 大きいタイトル用の領域を使わず、内容を画面上部から表示する。
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("予定を追加")
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
            .sheet(item: $editingRoutine) { routine in
                RoutineFormView(routine: routine, navigationTitle: "習慣を編集") { saved in
                    store.update(saved)
                } onDelete: {
                    store.delete(routine)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                SlackerFloatingButton(tab: 1)
                    .padding(.trailing, 4)
                    .padding(.bottom, 10)
            }
        }
    }

    /// 「今日」の直近の時刻から 1 時間の予定を初期値にする
    private func newEvent() -> Event {
        let start = Date()
        return Event(title: "",
                     start: start,
                     end: start.addingTimeInterval(3600),
                     category: .routine)
    }
}

#Preview {
    TodayView()
        .environment(AppStore.preview)
        .environment(SlackerConversationStore())
        .environment(SlackerNavigationStore())
}
