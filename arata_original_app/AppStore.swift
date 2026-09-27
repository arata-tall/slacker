import Foundation
import Observation

/// アプリ全体で予定とタスクを保持する唯一のデータストア。
/// 変更は必ずこのクラスのメソッド経由で行い、その都度 JSON としてディスクへ保存する。
@Observable
final class AppStore {
    private(set) var events: [Event]
    private(set) var tasks: [TaskItem]
    /// 毎週繰り返す固定の予定（時間割・睡眠・習い事など）
    private(set) var routines: [RoutineSchedule]

    private let fileURL: URL
    /// 読み込み中の保存を防ぐフラグ
    private var isLoading = false

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.events = []
        self.tasks = []
        self.routines = []
        load()
    }

    // MARK: - 予定の操作

    /// 指定日の予定を開始時刻順に並べて返す。習慣から作られる予定もここで合流する。
    func events(on day: Date) -> [Event] {
        (events.filter { $0.occurs(on: day) } + routineEvents(on: day))
            .sorted { lhs, rhs in
                // 終日の予定を先頭にまとめ、それ以外は開始時刻順
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                return lhs.start < rhs.start
            }
    }

    /// 習慣から、その日にかかる予定を組み立てる。
    /// 睡眠のように日をまたぐものがあるため、前日始まりの分も見る。
    private func routineEvents(on day: Date, calendar: Calendar = .current) -> [Event] {
        var result: [Event] = []

        for routine in routines {
            for offset in -1...0 {
                guard let base = calendar.date(byAdding: .day, value: offset, to: day),
                      let event = routine.occurrence(startingOn: base, calendar: calendar),
                      event.occurs(on: day, calendar: calendar) else { continue }
                result.append(event)
            }
        }
        return result
    }

    /// 今日から指定日数ぶんの予定（習慣を含む）。AI に渡す空き時間の判断材料に使う。
    func upcomingEvents(days: Int, calendar: Calendar = .current) -> [Event] {
        let today = calendar.startOfDay(for: Date())

        return (0..<days).flatMap { offset -> [Event] in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return [] }
            return events(on: day)
        }
    }

    func add(_ event: Event) {
        events.append(event)
        save()
    }

    func update(_ event: Event) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[index] = event
        save()
    }

    func delete(_ event: Event) {
        events.removeAll { $0.id == event.id }
        save()
    }

    // MARK: - 習慣の操作

    func routine(id: UUID) -> RoutineSchedule? {
        routines.first { $0.id == id }
    }

    func add(_ routine: RoutineSchedule) {
        routines.append(routine)
        save()
    }

    func update(_ routine: RoutineSchedule) {
        guard let index = routines.firstIndex(where: { $0.id == routine.id }) else { return }
        routines[index] = routine
        save()
    }

    func delete(_ routine: RoutineSchedule) {
        routines.removeAll { $0.id == routine.id }
        save()
    }

    // MARK: - タスクの操作

    /// 一覧に表示するタスク（ゴミ箱にあるものは除く）
    var activeTasks: [TaskItem] {
        tasks.filter { !$0.isDeleted }
    }

    /// ゴミ箱にあるタスク。削除した順に新しいものから並べる。
    var deletedTasks: [TaskItem] {
        tasks
            .filter { $0.isDeleted }
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    func add(_ task: TaskItem) {
        tasks.append(task)
        save()
    }

    /// ゴミ箱へ移す（データは残るので後から元に戻せる）
    func delete(_ task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].deletedAt = Date()
        save()
    }

    /// ゴミ箱から一覧へ戻す
    func restore(_ task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].deletedAt = nil
        save()
    }

    /// ゴミ箱から完全に削除する（元に戻せない）
    func permanentlyDelete(_ task: TaskItem) {
        tasks.removeAll { $0.id == task.id }
        save()
    }

    /// ゴミ箱を空にする（元に戻せない）
    func emptyTrash() {
        tasks.removeAll { $0.isDeleted }
        save()
    }

    // MARK: - 永続化

    private struct Snapshot: Codable {
        var events: [Event]
        var tasks: [TaskItem]
        /// 習慣を持たない頃に保存されたファイルも読めるようにする
        var routines: [RoutineSchedule]?
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = base.appendingPathComponent("arata_original_app", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("store.json")
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }

        guard let data = try? Data(contentsOf: fileURL) else {
            // 初回起動時はサンプルデータを入れておく
            events = Self.sampleEvents()
            tasks = Self.sampleTasks()
            save()
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(Snapshot.self, from: data) else {
            // 壊れたファイルは読み飛ばす（クラッシュさせない）
            return
        }

        events = snapshot.events
        tasks = snapshot.tasks
        routines = snapshot.routines ?? []
    }

    private func save() {
        guard !isLoading else { return }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let snapshot = Snapshot(events: events, tasks: tasks, routines: routines)
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - 初回起動時のサンプル

    private static func sampleEvents() -> [Event] {
        let calendar = Calendar.current
        let today = Date()

        func time(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
        }

        return [
            Event(title: "プロジェクト進捗報告会", location: "会議室A",
                  start: time(10, 0), end: time(10, 30), category: .routine),
            Event(title: "プレゼンの仕上げ", location: "デスク",
                  start: time(10, 30), end: time(11, 30), category: .assignment)
        ]
    }

    private static func sampleTasks() -> [TaskItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        func day(after days: Int) -> Date {
            calendar.date(byAdding: .day, value: days, to: today) ?? today
        }

        return [
            TaskItem(title: "プログラミングの学習", dueDate: day(after: 0), category: .assignment),
            TaskItem(title: "買い物（牛乳、卵）", dueDate: day(after: 1), category: .routine),
            TaskItem(title: "部屋の掃除", dueDate: day(after: 2), category: .routine),
            TaskItem(title: "読書（30ページ読む）", dueDate: day(after: 3), category: .leisure)
        ]
    }
}

extension AppStore {
    /// プレビュー用（ディスクに書き込まない一時ファイルを使う）
    static var preview: AppStore {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("preview-\(UUID().uuidString).json")
        return AppStore(fileURL: url)
    }
}
