import SwiftUI

/// 提案に対するユーザーの判断
enum ProposalDecision: String, Equatable {
    /// まだ返事をしていない
    case pending
    /// 承認して保存済み
    case approved
    /// 修正を依頼中
    case revising
    /// 見送った
    case rejected
}

/// AI の提案内容と、承認 / 修正 / 拒否のボタンを出すカード
struct ProposalCardView: View {
    let proposal: PlanProposal
    let decision: ProposalDecision

    let onApprove: () -> Void
    let onRevise: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("この内容で登録しますか？", systemImage: "sparkles")
                .font(.subheadline)
                .fontWeight(.semibold)

            if !proposal.events.isEmpty {
                section(title: "カレンダーに追加", systemImage: "calendar") {
                    ForEach(proposal.events) { event in
                        itemRow(title: event.title,
                                detail: event.timeRangeText,
                                extra: event.location?.isEmpty == false ? event.location : nil,
                                reason: event.reason,
                                accent: event.eventCategory.color,
                                badge: event.eventCategory.title)
                    }
                }
            }

            if !proposal.tasks.isEmpty {
                section(title: "タスクに追加", systemImage: "checklist") {
                    ForEach(proposal.tasks) { task in
                        itemRow(title: task.title,
                                detail: "期限: \(task.dueDateText)",
                                extra: nil,
                                reason: task.reason,
                                accent: task.taskCategory.color,
                                badge: task.taskCategory.title)
                    }
                }
            }

            Divider()

            footer
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.accentColor.opacity(decision == .pending ? 0.4 : 0), lineWidth: 1)
        )
    }

    // MARK: - パーツ

    @ViewBuilder
    private func section<Content: View>(title: String,
                                        systemImage: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            content()
        }
    }

    private func itemRow(title: String,
                         detail: String,
                         extra: String?,
                         reason: String?,
                         accent: Color,
                         badge: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(badge)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(accent.opacity(0.2), in: Capsule())
                        .foregroundStyle(accent)
                }

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let extra {
                    Label(extra, systemImage: "mappin.and.ellipse")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let reason, !reason.isEmpty {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var footer: some View {
        switch decision {
        case .pending:
            VStack(spacing: 8) {
                Button(action: onApprove) {
                    Label("承認して登録", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                HStack(spacing: 8) {
                    Button(action: onRevise) {
                        Label("修正する", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive, action: onReject) {
                        Label("拒否", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }

        case .approved:
            Label("カレンダーとタスクに登録しました", systemImage: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.green)

        case .revising:
            Label("修正内容を入力してください", systemImage: "pencil")
                .font(.footnote)
                .foregroundStyle(.secondary)

        case .rejected:
            Label("この提案は見送りました", systemImage: "xmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ProposalCardView(
        proposal: PlanProposal(
            events: [
                ProposedEvent(title: "スクールカップ 締め切り",
                              start: "2026-08-30T20:00",
                              end: "2026-08-30T20:00",
                              category: "assignment",
                              reason: "ご指定の締め切り時刻です"),
                ProposedEvent(title: "スクールカップ 提出物の作成",
                              start: "2026-08-30T14:00",
                              end: "2026-08-30T16:00",
                              category: "assignment",
                              reason: "既存の予定がない空き時間です")
            ],
            tasks: [
                ProposedTask(title: "スクールカップの提出", dueDate: "2026-08-30",
                             category: "assignment", reason: "締め切り当日を期限にしました")
            ]
        ),
        decision: .pending,
        onApprove: {}, onRevise: {}, onReject: {}
    )
    .padding()
}
