import SwiftUI

/// 登録済みの習慣（固定予定）の一覧。ここからまとめて追加・編集できる。
struct RoutineListView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var adding: RoutineSchedule?
    @State private var editing: RoutineSchedule?

    /// 曜日の早い順・時刻順に並べる
    private var sortedRoutines: [RoutineSchedule] {
        store.routines.sorted { lhs, rhs in
            let lhsDay = lhs.weekdays.min() ?? 8
            let rhsDay = rhs.weekdays.min() ?? 8
            if lhsDay != rhsDay { return lhsDay < rhsDay }
            return (lhs.startHour * 60 + lhs.startMinute) < (rhs.startHour * 60 + rhs.startMinute)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                presetSection

                if !sortedRoutines.isEmpty {
                    Section("登録済み（\(sortedRoutines.count)件）") {
                        ForEach(sortedRoutines) { routine in
                            Button {
                                editing = routine
                            } label: {
                                row(for: routine)
                            }
                        }
                    }
                }
            }
            .overlay {
                if sortedRoutines.isEmpty {
                    ContentUnavailableView(
                        "固定の予定はまだありません",
                        systemImage: "repeat",
                        description: Text("上のボタンから、時間割・睡眠・習い事などをまとめて登録できます")
                    )
                    // 上のプリセット部分は隠さない
                    .padding(.top, 220)
                }
            }
            .navigationTitle("習慣・固定予定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        adding = RoutineSchedule(title: "")
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("習慣を追加")
                }
            }
            .sheet(item: $adding) { routine in
                RoutineFormView(routine: routine, navigationTitle: "習慣を追加") { saved in
                    store.add(saved)
                }
            }
            .sheet(item: $editing) { routine in
                RoutineFormView(routine: routine, navigationTitle: "習慣を編集") { saved in
                    store.update(saved)
                } onDelete: {
                    store.delete(routine)
                }
            }
            .liquidGlassForm()
        }
    }

    // MARK: - パーツ

    /// よくある固定予定を下敷きにして、入力を短く済ませる
    private var presetSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(RoutineSchedule.presets) { preset in
                        Button {
                            adding = preset.schedule
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: preset.systemImage)
                                    .font(.title3)
                                Text(preset.title)
                                    .font(.caption)
                            }
                            .frame(width: 84, height: 68)
                            .background(Color(uiColor: .tertiarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 0))
        } header: {
            Text("よく使う型から追加")
        } footer: {
            Text("選ぶと時間と曜日が入った状態でフォームが開きます。時間割は「授業（1コマ）」から科目ごとに登録してください。")
        }
    }

    private func row(for routine: RoutineSchedule) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(routine.category.color)
                .frame(width: 4)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(routine.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(routine.isEnabled ? .primary : .secondary)

                    if !routine.isEnabled {
                        Text("停止中")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.2), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }

                Text("\(routine.weekdaysText)　\(routine.timeRangeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !routine.location.isEmpty {
                    Label(routine.location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let endDate = routine.endDate {
                    Text("〜 \(endDate.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(.app)))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .liquidGlassCard(cornerRadius: 14)
        .swipeActions {
            Button("削除", role: .destructive) {
                store.delete(routine)
            }
        }
    }
}

#Preview {
    RoutineListView()
        .environment(AppStore.preview)
}
