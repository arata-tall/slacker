import SwiftUI
import PhotosUI
import UIKit
import Observation

/// このアプリのAIアシスタントの名前。表示名を変えるときはここだけ直せばよい。
enum Slacker {
    static let name = "Slacker"
}

// チャットメッセージのデータモデル
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
    /// 添付画像（JPEG）。送信時に縮小してから保持する。
    var imageData: Data?
    /// AI が提案した予定・タスク（提案がないときは nil）
    var proposal: PlanProposal?
    /// 提案に対するユーザーの判断
    var decision: ProposalDecision = .pending
    let timestamp = Date()
}

/// Slackerの会話履歴を、どの画面から開いても共有するためのストア。
@Observable
final class SlackerConversationStore {
    var messages: [ChatMessage] = [
        ChatMessage(text: "こんにちは！何かお手伝いできることはありますか？", isUser: false)
    ]
}

struct SlackerView: View {
    @Environment(AppStore.self) private var store
    @Environment(SlackerConversationStore.self) private var conversation

    // APIキーとモデル名はソースに書かず、設定画面から入力して端末に保存する。
    // 保存キーは名称変更前のままにしてある（変えると保存済みの値が読めなくなるため）。
    @AppStorage("geminiAPIKey") private var apiKey: String = ""
    @AppStorage("geminiModel") private var model: String = GeminiService.defaultModel

    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var showSettings = false

    // 添付画像
    @State private var pickedItem: PhotosPickerItem?
    @State private var attachedImageData: Data?
    @State private var isPreparingImage = false

    @FocusState private var isInputFocused: Bool

    private var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSend: Bool {
        let hasText = !inputText.trimmingCharacters(in: .whitespaces).isEmpty
        return (hasText || attachedImageData != nil) && !isLoading && !isPreparingImage
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !hasAPIKey {
                    apiKeyBanner
                }

                messageList

                Divider()

                if attachedImageData != nil || isPreparingImage {
                    attachmentPreview
                }

                inputBar
            }
            .navigationTitle(Slacker.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "key")
                    }
                    .accessibilityLabel("APIキーとモデルの設定")
                }
            }
            .sheet(isPresented: $showSettings) {
                APIKeySettingsView(apiKey: $apiKey, model: $model)
            }
            .onChange(of: pickedItem) {
                loadPickedImage()
            }
            .liquidGlassScreen()
        }
    }

    // MARK: - パーツ

    private var apiKeyBanner: some View {
        Button {
            showSettings = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                Text("APIキー未設定のためサンプル応答を返します")
                Spacer()
                Image(systemName: "chevron.right").font(.footnote)
            }
            .font(.footnote)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .liquidGlassCard(cornerRadius: 0)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(conversation.messages) { message in
                        VStack(alignment: .leading, spacing: 10) {
                            ChatBubble(message: message)

                            if let proposal = message.proposal, !proposal.isEmpty {
                                ProposalCardView(
                                    proposal: proposal,
                                    decision: message.decision,
                                    onApprove: { approve(message) },
                                    onRevise: { requestRevision(message) },
                                    onReject: { reject(message) }
                                )
                                .padding(.horizontal)
                            }
                        }
                        .id(message.id)
                    }

                    if isLoading {
                        HStack {
                            ProgressView()
                                .padding(10)
                                .liquidGlassCard(cornerRadius: 12)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .id(Self.loadingIndicatorID)
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: conversation.messages.count) {
                scrollToBottom(proxy)
            }
            .onChange(of: isLoading) {
                scrollToBottom(proxy)
            }
        }
    }

    /// 送信前の添付画像のサムネイル
    private var attachmentPreview: some View {
        HStack(spacing: 12) {
            if isPreparingImage {
                ProgressView()
                    .frame(width: 60, height: 60)
                Text("画像を準備しています…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if let attachedImageData, let image = UIImage(data: attachedImageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("画像を添付中")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    self.attachedImageData = nil
                    pickedItem = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("添付を取り消す")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .liquidGlassCard(cornerRadius: 18)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $pickedItem, matching: .images, photoLibrary: .shared()) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 20))
                    .foregroundStyle(isLoading ? Color.gray : Color.accentColor)
            }
            .disabled(isLoading)
            .accessibilityLabel("画像を添付")

            TextField("\(Slacker.name)にメッセージを送信...", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .padding(10)
                .liquidGlassCard(cornerRadius: 20)
                .disabled(isLoading)
                .focused($isInputFocused)
                .onSubmit(send)

            Button(action: send) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(canSend ? Color.accentColor : Color.gray)
            }
            .disabled(!canSend)
            .accessibilityLabel("送信")
        }
        .padding()
    }

    // MARK: - 画像の読み込み

    private func loadPickedImage() {
        guard let pickedItem else { return }
        isPreparingImage = true

        Task {
            let data = try? await pickedItem.loadTransferable(type: Data.self)
            // 大きすぎる写真をそのまま送らないよう、長辺 1024px の JPEG に落とす
            attachedImageData = data.flatMap { Self.downscaledJPEG(from: $0) }
            isPreparingImage = false
        }
    }

    private static func downscaledJPEG(from data: Data, maxDimension: CGFloat = 1024) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension else {
            return image.jpegData(compressionQuality: 0.8)
        }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }

    // MARK: - 送信

    private static let loadingIndicatorID = "loading-indicator"

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation {
            if isLoading {
                proxy.scrollTo(Self.loadingIndicatorID, anchor: .bottom)
            } else if let last = conversation.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func send() {
        guard canSend else { return }

        let userText = inputText.trimmingCharacters(in: .whitespaces)
        let image = attachedImageData

        conversation.messages.append(ChatMessage(text: userText, isUser: true, imageData: image))
        inputText = ""
        attachedImageData = nil
        pickedItem = nil
        isLoading = true

        Task {
            let reply = await reply(to: userText, hasImage: image != nil)
            conversation.messages.append(reply)
            isLoading = false
        }
    }

    private func reply(to userText: String, hasImage: Bool) async -> ChatMessage {
        guard hasAPIKey else {
            // キー未設定のときは通信せずサンプル応答を返す
            try? await Task.sleep(for: .seconds(1.2))
            let subject = userText.isEmpty ? "画像" : "「\(userText)」\(hasImage ? "と画像" : "")"
            return ChatMessage(
                text: "\(subject)ですね！APIキーを設定すると、実際の回答が表示されます。",
                isUser: false
            )
        }

        do {
            let reply = try await GeminiService.send(history: conversation.messages,
                                                     existingEvents: store.upcomingEvents(days: 14),
                                                     apiKey: apiKey,
                                                     model: model)
            let proposal = reply.proposal
            return ChatMessage(text: reply.message,
                               isUser: false,
                               proposal: proposal.isEmpty ? nil : proposal)
        } catch {
            return ChatMessage(text: "エラー: \(error.localizedDescription)", isUser: false)
        }
    }

    // MARK: - 提案への応答

    /// 承認：提案をカレンダーとタスクに保存する
    private func approve(_ message: ChatMessage) {
        guard let index = conversation.messages.firstIndex(where: { $0.id == message.id }),
              let proposal = message.proposal else { return }

        var savedEvents = 0
        var savedTasks = 0
        var failed: [String] = []
        let calendar = Calendar.current
        // AI が「課題の予定」と同内容のタスクも提案した場合だけ、後者を重複登録しない。
        // 課題カテゴリの予定自体はすべてタスク化する。
        var taskKeysCreatedFromAssignmentEvents: Set<String> = []

        func taskKey(title: String, dueDate: Date) -> String {
            let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            let day = calendar.startOfDay(for: dueDate)
            return "\(normalizedTitle)|\(PlanDateParser.string(from: day, includeTime: false))"
        }

        for proposed in proposal.events {
            if let event = proposed.makeEvent() {
                store.add(event)
                savedEvents += 1

                // AI が課題として提案した予定は、終了日時を期限にしてタスク一覧にも出す。
                if event.category == .assignment {
                    let task = TaskItem(title: event.title,
                                        dueDate: event.end,
                                        category: event.category)
                    store.add(task)
                    savedTasks += 1
                    taskKeysCreatedFromAssignmentEvents.insert(taskKey(title: task.title,
                                                                        dueDate: task.dueDate))
                }
            } else {
                failed.append(proposed.title)
            }
        }

        for proposed in proposal.tasks {
            if let task = proposed.makeTask() {
                let key = taskKey(title: task.title, dueDate: task.dueDate)
                if !taskKeysCreatedFromAssignmentEvents.contains(key) {
                    store.add(task)
                    savedTasks += 1
                }
            } else {
                failed.append(proposed.title)
            }
        }

        withAnimation {
            conversation.messages[index].decision = .approved
            conversation.messages.append(ChatMessage(text: approvalSummary(events: savedEvents,
                                                                           tasks: savedTasks,
                                                                           failed: failed),
                                                     isUser: false))
        }
    }

    private func approvalSummary(events: Int, tasks: Int, failed: [String]) -> String {
        var lines: [String] = []

        if events > 0 { lines.append("カレンダーに\(events)件の予定を追加しました。") }
        if tasks > 0 { lines.append("タスクに\(tasks)件追加しました。") }
        if lines.isEmpty { lines.append("追加できる項目がありませんでした。") }

        if !failed.isEmpty {
            lines.append("日時を解釈できなかったため、次の項目は登録していません: \(failed.joined(separator: "、"))")
        }
        return lines.joined(separator: "\n")
    }

    /// 修正：入力欄にフォーカスを移し、修正内容を書いてもらう
    private func requestRevision(_ message: ChatMessage) {
        guard let index = conversation.messages.firstIndex(where: { $0.id == message.id }) else { return }

        withAnimation {
            conversation.messages[index].decision = .revising
        }
        isInputFocused = true
    }

    /// 拒否：何も保存せずに終える
    private func reject(_ message: ChatMessage) {
        guard let index = conversation.messages.firstIndex(where: { $0.id == message.id }) else { return }

        withAnimation {
            conversation.messages[index].decision = .rejected
            conversation.messages.append(ChatMessage(text: "承知しました。この提案は登録しません。", isUser: false))
        }
    }
}

// MARK: - APIキーとモデルの設定画面

struct APIKeySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var apiKey: String
    @Binding var model: String

    @State private var keyDraft: String = ""
    @State private var modelDraft: String = ""

    private var trimmedModel: String {
        modelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("APIキーを貼り付け", text: $keyDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Gemini APIキー")
                } footer: {
                    Text("Google AI Studio で取得したキーを入力してください。キーはこの端末にのみ保存され、送信先は Google の API のみです。未設定の場合はサンプル応答が返ります。")
                }

                Section {
                    TextField(GeminiService.defaultModel, text: $modelDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if trimmedModel != GeminiService.defaultModel {
                        Button("既定（\(GeminiService.defaultModel)）に戻す") {
                            modelDraft = GeminiService.defaultModel
                        }
                    }
                } header: {
                    Text("モデル")
                } footer: {
                    Text("提供されるモデルは入れ替わります。「is no longer available」といったエラーが出たら、案内された新しいモデル名をここに入力してください。")
                }

                if !apiKey.isEmpty {
                    Section {
                        Button("保存済みのキーを削除", role: .destructive) {
                            apiKey = ""
                            keyDraft = ""
                        }
                    }
                }
            }
            .navigationTitle("\(Slacker.name)の設定")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                keyDraft = apiKey
                modelDraft = model
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        apiKey = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        // 空欄で保存されるとリクエストが作れないため既定に戻す
                        model = trimmedModel.isEmpty ? GeminiService.defaultModel : trimmedModel
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// チャット吹き出しコンポーネント
struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 40) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                if let imageData = message.imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if !message.text.isEmpty {
                    // モデルの返答は Markdown で返ってくるので装飾を反映する。
                    // ユーザーの入力はそのまま（打った記号が勝手に装飾されないように）。
                    Text(message.isUser ? AttributedString(message.text) : Self.markdown(message.text))
                        .textSelection(.enabled)
                }
            }
            .padding(12)
            .background(message.isUser ? Color.accentColor : Color.white.opacity(0.18))
            .foregroundStyle(message.isUser ? Color.white : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                if !message.isUser {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.65), lineWidth: 1)
                }
            }

            if !message.isUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal)
    }

    /// Markdown として解釈する。解釈できない場合は元の文字列をそのまま表示する。
    ///
    /// `**強調**` は自前で処理する。CommonMark の規則では `**「` のように
    /// 記号が隣接すると強調として扱われず、日本語の文章では `**` がそのまま
    /// 残ってしまうため。
    private static func markdown(_ text: String) -> AttributedString {
        let segments = text.components(separatedBy: "**")

        // `**` が奇数個なら対応が取れないので、通常の解釈だけ行う
        guard segments.count > 1, segments.count % 2 == 1 else {
            return inlineMarkdown(text)
        }

        var result = AttributedString()
        for (index, segment) in segments.enumerated() {
            var piece = inlineMarkdown(segment)
            if index.isMultiple(of: 2) == false {
                piece.inlinePresentationIntent = .stronglyEmphasized
            }
            result.append(piece)
        }
        return result
    }

    /// 強調以外（斜体・コード・リンクなど）の解釈
    private static func inlineMarkdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

#Preview {
    SlackerView()
        .environment(AppStore.preview)
        .environment(SlackerConversationStore())
}
