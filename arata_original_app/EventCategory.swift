import SwiftUI

/// 予定・タスクの性質。色はこのカテゴリで決まる。
/// rawValue は保存データのキーになるため、表示名を変えても書き換えないこと。
enum EventCategory: String, CaseIterable, Identifiable, Codable {
    /// 課題・提出物・仕事のタスクなど
    case assignment
    /// 遊び・趣味・友人との予定など
    case leisure
    /// 学校や会社など、繰り返しの基本予定
    case routine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .assignment: return "課題"
        case .leisure: return "遊び"
        case .routine: return "基本予定"
        }
    }

    var detail: String {
        switch self {
        case .assignment: return "課題・提出物・締め切りのある作業"
        case .leisure: return "遊び・趣味・友人との予定"
        case .routine: return "学校や会社など、決まった時間の予定"
        }
    }

    /// 初期設定の色
    var defaultHex: String {
        switch self {
        case .assignment: return "#E5484D"  // 赤
        case .leisure: return "#3B82F6"     // 青
        case .routine: return "#EAB308"     // 黄
        }
    }

    /// ユーザー設定を反映した実際の表示色
    var color: Color { ThemeSettings.shared.color(for: self) }

    /// 旧バージョン（15色）のデータを読み込むときの対応付け
    static func fromLegacyColorName(_ name: String?) -> EventCategory {
        switch name {
        case "ワイン", "ローズ", "フラミンゴ", "トマト":
            return .assignment
        case "アボカド", "ピスタチオ", "バジル", "セージ", "ピーコック", "コバルト":
            return .leisure
        default:
            // ミカン・カボチャ・マンゴー・バナナ・レモン、および不明な値
            return .routine
        }
    }
}

/// カテゴリごとの色設定。UserDefaults に保存し、アプリ全体で共有する。
@Observable
final class ThemeSettings {
    static let shared = ThemeSettings()

    private static let storageKey = "categoryColors"

    /// カテゴリの rawValue → 16進数の色
    private var hexes: [String: String]

    private init() {
        hexes = UserDefaults.standard.dictionary(forKey: Self.storageKey) as? [String: String] ?? [:]
    }

    func color(for category: EventCategory) -> Color {
        Color(hex: hexes[category.rawValue] ?? category.defaultHex)
            ?? Color(hex: category.defaultHex)
            ?? .gray
    }

    func setColor(_ color: Color, for category: EventCategory) {
        hexes[category.rawValue] = color.hexString
        save()
    }

    /// 全カテゴリを初期設定の色に戻す
    func resetToDefaults() {
        hexes = [:]
        save()
    }

    /// ひとつでも初期設定から変更されているか
    var isCustomized: Bool {
        EventCategory.allCases.contains { hexes[$0.rawValue] != nil }
    }

    private func save() {
        UserDefaults.standard.set(hexes, forKey: Self.storageKey)
    }
}

// MARK: - Color と 16進数文字列の相互変換

extension Color {
    /// "#RRGGBB" から生成する
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }

        self.init(
            red: Double((number & 0xFF0000) >> 16) / 255,
            green: Double((number & 0x00FF00) >> 8) / 255,
            blue: Double(number & 0x0000FF) / 255
        )
    }

    /// "#RRGGBB" に変換する
    var hexString: String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return String(format: "#%02X%02X%02X",
                      Int((red * 255).rounded()),
                      Int((green * 255).rounded()),
                      Int((blue * 255).rounded()))
    }
}
