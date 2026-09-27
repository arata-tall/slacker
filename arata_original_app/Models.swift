import SwiftUI

// MARK: - 表示用ロケール
// UI が日本語固定のため、日付・時刻も端末設定に関わらず日本語表記で統一する。
extension Locale {
    static let app = Locale(identifier: "ja_JP")
}

// MARK: - 予定
// カレンダー画面と今日の予定画面が共有する唯一の予定モデル。
// 時刻は文字列ではなく Date で保持する（並べ替え・比較・ロケール対応のため）。
struct Event: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var title: String
    var location: String = ""
    var start: Date
    var end: Date
    var isAllDay: Bool = false
    /// 予定の性質。表示色はここから決まる。
    var category: EventCategory = .routine
    /// 習慣（RoutineSchedule）から組み立てた予定なら、その習慣の ID。
    /// 単発の予定は nil。
    var routineID: UUID?

    var color: Color { category.color }

    var isFromRoutine: Bool { routineID != nil }

    /// この予定が指定日のものかどうか（終日予定は開始日〜終了日の範囲で判定）
    func occurs(on day: Date, calendar: Calendar = .current) -> Bool {
        let target = calendar.startOfDay(for: day)
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: end)
        return target >= from && target <= to
    }

    /// 一覧に表示する時間帯の文字列（24時間表記なので開始・終了の午前午後を取り違えない）
    var timeRangeText: String {
        if isAllDay { return "終日" }
        let style = Date.FormatStyle(date: .omitted, time: .shortened).locale(.app)
        return "\(start.formatted(style)) 〜 \(end.formatted(style))"
    }

    /// 指定日に占める長さ（分）。カレンダーの色の比率に使う。
    /// 締め切りのような長さ 0 の予定も見えるよう、下限を設けている。
    func minutes(on day: Date, calendar: Calendar = .current) -> Double {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return 0 }

        let from = max(start, dayStart)
        let to = min(max(end, start), dayEnd)
        let minutes = max(0, to.timeIntervalSince(from)) / 60
        return max(minutes, 30)
    }

    // 旧バージョン（15色の color を持つデータ）も読めるようにする
    private enum CodingKeys: String, CodingKey {
        case id, title, location, start, end, isAllDay, category, routineID
        /// 旧データのみに存在する
        case color
    }

    init(id: UUID = UUID(),
         title: String,
         location: String = "",
         start: Date,
         end: Date,
         isAllDay: Bool = false,
         category: EventCategory = .routine,
         routineID: UUID? = nil) {
        self.id = id
        self.title = title
        self.location = location
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.category = category
        self.routineID = routineID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        start = try container.decode(Date.self, forKey: .start)
        end = try container.decode(Date.self, forKey: .end)
        isAllDay = try container.decodeIfPresent(Bool.self, forKey: .isAllDay) ?? false
        routineID = try container.decodeIfPresent(UUID.self, forKey: .routineID)

        if let category = try container.decodeIfPresent(EventCategory.self, forKey: .category) {
            self.category = category
        } else {
            let legacy = try container.decodeIfPresent(String.self, forKey: .color)
            self.category = EventCategory.fromLegacyColorName(legacy)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(location, forKey: .location)
        try container.encode(start, forKey: .start)
        try container.encode(end, forKey: .end)
        try container.encode(isAllDay, forKey: .isAllDay)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(routineID, forKey: .routineID)
    }
}

// MARK: - タスク
struct TaskItem: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var title: String
    var dueDate: Date
    /// 削除した日時。nil なら一覧に表示され、値が入っていればゴミ箱にある。
    var deletedAt: Date?
    /// タスクの性質。表示色はここから決まる。
    var category: EventCategory = .assignment

    var isDeleted: Bool { deletedAt != nil }

    var color: Color { category.color }

    var dueDateText: String {
        dueDate.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(.app))
    }

    /// タスク一覧では開始時刻を持たないため、終了（期限）時刻だけを表示する。
    var dueTimeText: String {
        dueDate.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(.app))
    }

    var deletedAtText: String? {
        guard let deletedAt else { return nil }
        return deletedAt.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(.app))
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, dueDate, deletedAt, category
    }

    init(id: UUID = UUID(),
         title: String,
         dueDate: Date,
         deletedAt: Date? = nil,
         category: EventCategory = .assignment) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.deletedAt = deletedAt
        self.category = category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        // カテゴリを持たない旧データは課題として扱う
        category = try container.decodeIfPresent(EventCategory.self, forKey: .category) ?? .assignment
    }
}
