import Foundation

/// AI が提案した予定・タスクのまとまり。ユーザーが承認するまで保存はしない。
struct PlanProposal: Equatable, Codable {
    var events: [ProposedEvent] = []
    var tasks: [ProposedTask] = []

    var isEmpty: Bool { events.isEmpty && tasks.isEmpty }
}

/// 提案された予定（API から届く生の形。日時は文字列で受け取り、ここで Date に変換する）
struct ProposedEvent: Equatable, Codable, Identifiable {
    var id = UUID()

    var title: String
    var location: String?
    /// "2026-08-30T20:00" 形式
    var start: String
    var end: String?
    var isAllDay: Bool?
    /// EventCategory の rawValue（assignment / leisure / routine）
    var category: String?
    /// なぜこの日時にしたのかの説明
    var reason: String?

    // API は id を返さないので、デコード対象から外す
    private enum CodingKeys: String, CodingKey {
        case title, location, start, end, isAllDay, category, reason
    }

    var startDate: Date? { PlanDateParser.date(from: start) }

    var endDate: Date? {
        guard let startDate else { return nil }
        guard let end, let parsed = PlanDateParser.date(from: end) else {
            return startDate.addingTimeInterval(3600)
        }
        return max(parsed, startDate)
    }

    /// 保存用の Event に変換する。日時を解釈できない場合は nil。
    func makeEvent() -> Event? {
        guard let startDate, let endDate else { return nil }
        return Event(title: title,
                     location: location ?? "",
                     start: startDate,
                     end: endDate,
                     isAllDay: isAllDay ?? false,
                     category: eventCategory)
    }

    /// AI が返したカテゴリ。解釈できない場合は基本予定として扱う。
    var eventCategory: EventCategory {
        category.flatMap(EventCategory.init(rawValue:)) ?? .routine
    }

    /// 一覧に出す時間帯の文字列
    var timeRangeText: String {
        guard let event = makeEvent() else { return start }
        let date = event.start.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted).locale(.app)
        )
        return "\(date) \(event.timeRangeText)"
    }
}

/// 提案されたタスク
struct ProposedTask: Equatable, Codable, Identifiable {
    var id = UUID()

    var title: String
    /// "2026-08-30" 形式
    var dueDate: String
    /// EventCategory の rawValue
    var category: String?
    var reason: String?

    private enum CodingKeys: String, CodingKey {
        case title, dueDate, category, reason
    }

    /// AI が返したカテゴリ。解釈できない場合は課題として扱う。
    var taskCategory: EventCategory {
        category.flatMap(EventCategory.init(rawValue:)) ?? .assignment
    }

    func makeTask() -> TaskItem? {
        guard let due = PlanDateParser.date(from: dueDate) else { return nil }
        return TaskItem(title: title, dueDate: due, category: taskCategory)
    }

    var dueDateText: String {
        guard let task = makeTask() else { return dueDate }
        return task.dueDateText
    }
}

/// AI からの応答ひとまとまり（会話文＋提案）
struct GeminiReply: Equatable, Codable {
    var message: String
    var events: [ProposedEvent]?
    var tasks: [ProposedTask]?

    var proposal: PlanProposal {
        PlanProposal(events: events ?? [], tasks: tasks ?? [])
    }
}

/// AI が返す日時文字列を Date にする。表記ゆれをいくつか受け付ける。
enum PlanDateParser {
    private static let formats = [
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd HH:mm",
        "yyyy-MM-dd",
        "yyyy/MM/dd HH:mm",
        "yyyy/MM/dd"
    ]

    static func date(from string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // タイムゾーン指定が付いていた場合はまず ISO8601 として試す
        if trimmed.hasSuffix("Z") || trimmed.contains("+") {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: trimmed) { return date }
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }

    /// AI に渡す日時の文字列表現
    static func string(from date: Date, includeTime: Bool = true) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = includeTime ? "yyyy-MM-dd'T'HH:mm" : "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
