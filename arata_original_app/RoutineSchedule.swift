import Foundation

/// 毎週決まった曜日・時刻に繰り返す予定（時間割・睡眠・習い事など）。
/// 実際の予定を大量に作るのではなく、この 1 件のルールから毎回その日の予定を組み立てる。
struct RoutineSchedule: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var title: String
    var location: String = ""
    /// 繰り返す曜日。Calendar の .weekday と同じ 1=日曜 … 7=土曜。
    var weekdays: Set<Int> = []
    var startHour: Int = 9
    var startMinute: Int = 0
    var endHour: Int = 10
    var endMinute: Int = 0
    var category: EventCategory = .routine
    /// この日から有効
    var startDate: Date = Calendar.current.startOfDay(for: Date())
    /// この日まで有効（nil なら期限なし）
    var endDate: Date?
    /// 一時的に止めたいときは false
    var isEnabled: Bool = true
    /// カレンダーの日付のまわりの輪（忙しさの色の比率）に含めるかどうか。
    /// 睡眠のように毎日必ずある時間は、含めると全部の日が同じ色になってしまうため外せるようにしている。
    /// この項目を持たない古いデータのために Optional にしてある。
    var countsInDayRatio: Bool?

    /// 色の比率に含めるか。未設定の古いデータは、睡眠らしい名前なら除外して扱う。
    var countsInRatio: Bool {
        countsInDayRatio ?? !looksLikeSleep
    }

    private var looksLikeSleep: Bool {
        let name = title.lowercased()
        return ["睡眠", "寝る", "就寝", "sleep"].contains { name.contains($0) }
    }

    /// 終了時刻が開始時刻以下なら日をまたぐ（睡眠など）
    var crossesMidnight: Bool {
        (endHour * 60 + endMinute) <= (startHour * 60 + startMinute)
    }

    var timeRangeText: String {
        let start = String(format: "%02d:%02d", startHour, startMinute)
        let end = String(format: "%02d:%02d", endHour, endMinute)
        return crossesMidnight ? "\(start) 〜 翌\(end)" : "\(start) 〜 \(end)"
    }

    var weekdaysText: String {
        RoutineSchedule.weekdaysText(for: weekdays)
    }

    /// 指定日に始まる 1 回分の予定を組み立てる。その曜日でなければ nil。
    func occurrence(startingOn day: Date, calendar: Calendar = .current) -> Event? {
        guard isEnabled, !weekdays.isEmpty else { return nil }

        let dayStart = calendar.startOfDay(for: day)
        guard weekdays.contains(calendar.component(.weekday, from: dayStart)) else { return nil }
        guard dayStart >= calendar.startOfDay(for: startDate) else { return nil }
        if let endDate, dayStart > calendar.startOfDay(for: endDate) { return nil }

        guard let start = calendar.date(bySettingHour: startHour, minute: startMinute,
                                        second: 0, of: dayStart),
              var end = calendar.date(bySettingHour: endHour, minute: endMinute,
                                      second: 0, of: dayStart) else { return nil }

        if end <= start {
            end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        }

        return Event(id: .occurrence(routine: id, day: dayStart),
                     title: title,
                     location: location,
                     start: start,
                     end: end,
                     category: category,
                     routineID: id)
    }

    // MARK: - 曜日の表示

    /// 1=日曜 … 7=土曜
    static let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]

    static func symbol(for weekday: Int) -> String {
        weekdaySymbols[(weekday - 1 + 7) % 7]
    }

    static let weekdays平日: Set<Int> = [2, 3, 4, 5, 6]
    static let weekdays週末: Set<Int> = [1, 7]
    static let weekdays毎日: Set<Int> = [1, 2, 3, 4, 5, 6, 7]

    static func weekdaysText(for weekdays: Set<Int>) -> String {
        if weekdays.isEmpty { return "曜日が未設定" }
        if weekdays == weekdays毎日 { return "毎日" }
        if weekdays == weekdays平日 { return "平日（月〜金）" }
        if weekdays == weekdays週末 { return "土日" }

        return weekdays.sorted().map(symbol(for:)).joined(separator: "・")
    }

    // MARK: - よく使う型（登録を早くするための下敷き）

    struct Preset: Identifiable {
        var id: String { title }
        var title: String
        var systemImage: String
        var schedule: RoutineSchedule
    }

    static let presets: [Preset] = [
        Preset(title: "睡眠", systemImage: "moon.zzz",
               schedule: RoutineSchedule(title: "睡眠", weekdays: weekdays毎日,
                                         startHour: 23, startMinute: 0,
                                         endHour: 7, endMinute: 0,
                                         category: .routine,
                                         countsInDayRatio: false)),
        Preset(title: "学校", systemImage: "graduationcap",
               schedule: RoutineSchedule(title: "学校", weekdays: weekdays平日,
                                         startHour: 8, startMinute: 50,
                                         endHour: 15, endMinute: 30,
                                         category: .routine)),
        Preset(title: "授業（1コマ）", systemImage: "book",
               schedule: RoutineSchedule(title: "", weekdays: [],
                                         startHour: 9, startMinute: 0,
                                         endHour: 10, endMinute: 30,
                                         category: .routine)),
        Preset(title: "習い事", systemImage: "figure.run",
               schedule: RoutineSchedule(title: "", weekdays: [],
                                         startHour: 18, startMinute: 0,
                                         endHour: 19, endMinute: 30,
                                         category: .leisure)),
        Preset(title: "アルバイト", systemImage: "briefcase",
               schedule: RoutineSchedule(title: "アルバイト", weekdays: [],
                                         startHour: 17, startMinute: 0,
                                         endHour: 21, endMinute: 0,
                                         category: .routine))
    ]
}

extension UUID {
    /// 習慣の 1 回分に、毎回同じ ID を割り当てる。
    /// 画面の再描画で予定の並びがちらつかないようにするため。
    static func occurrence(routine: UUID, day: Date) -> UUID {
        let dayNumber = max(0, Int(day.timeIntervalSince1970 / 86_400))
        let base = routine.uuidString.replacingOccurrences(of: "-", with: "")

        let characters = Array(String(base.prefix(20)) + String(format: "%012llX", UInt64(dayNumber)))
        guard characters.count == 32 else { return UUID() }

        let formatted = String(characters[0..<8]) + "-"
            + String(characters[8..<12]) + "-"
            + String(characters[12..<16]) + "-"
            + String(characters[16..<20]) + "-"
            + String(characters[20..<32])

        return UUID(uuidString: formatted) ?? UUID()
    }
}
