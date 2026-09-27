import SwiftUI

/// 予定 1 件のカード表示。今日の予定画面とカレンダー画面で共用する。
struct EventRowView: View {
    let event: Event

    var body: some View {
        HStack(spacing: 12) {
            // 左側のアクセントライン
            RoundedRectangle(cornerRadius: 2)
                .fill(event.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    if event.isFromRoutine {
                        Image(systemName: "repeat")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(event.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }

                Text(event.timeRangeText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !event.location.isEmpty {
                    Label(event.location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(cornerRadius: 16)
    }
}

#Preview {
    EventRowView(event: Event(title: "プロジェクト進捗報告会", location: "会議室A",
                              start: .now, end: .now.addingTimeInterval(1800), category: .routine))
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
