import SwiftUI

/// カレンダーの日付を囲む輪の 1 区間
struct CategorySegment: Identifiable, Equatable {
    var category: EventCategory
    /// 0〜1。その日の予定の長さに占める割合。
    var fraction: Double

    var id: String { category.rawValue }
}

/// その日の予定を、種類ごとの割合で日付のまわりに輪として描く。
/// 予定がない日は何も描かない。
struct DayCategoryRing: View {
    let segments: [CategorySegment]
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            ForEach(Array(offsets.enumerated()), id: \.element.segment.id) { _, offset in
                Circle()
                    .trim(from: offset.start, to: offset.end)
                    .stroke(offset.segment.category.color,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    // 12時の位置から時計回りに描く
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(lineWidth / 2)
    }

    /// 各区間の開始・終了位置（0〜1）を積み上げて求める
    private var offsets: [(segment: CategorySegment, start: Double, end: Double)] {
        var result: [(CategorySegment, Double, Double)] = []
        var cursor: Double = 0

        for segment in segments where segment.fraction > 0 {
            let end = min(cursor + segment.fraction, 1)
            // 区間が細すぎると見えないので、わずかに下限を設ける
            result.append((segment, cursor, max(end, cursor + 0.02)))
            cursor = end
        }
        return result
    }
}

#Preview {
    HStack(spacing: 24) {
        DayCategoryRing(segments: [
            CategorySegment(category: .assignment, fraction: 1)
        ])
        .frame(width: 36, height: 36)
        .overlay(Text("1"))

        DayCategoryRing(segments: [
            CategorySegment(category: .assignment, fraction: 0.5),
            CategorySegment(category: .leisure, fraction: 0.25),
            CategorySegment(category: .routine, fraction: 0.25)
        ])
        .frame(width: 36, height: 36)
        .overlay(Text("15"))

        DayCategoryRing(segments: [])
            .frame(width: 36, height: 36)
            .overlay(Text("20"))
    }
    .padding()
}
