import Foundation

/// Gemini API（generateContent）への問い合わせを担当する。
///
/// APIキーはソースコードには置かず、アプリ内の設定画面から入力して端末に保存する。
/// 不特定多数に配布するアプリで共通のキーを使う場合は、キーを端末に置かず
/// 自前のサーバーを経由させること（バイナリからキーを抽出されるため）。
///
/// 応答は必ず JSON で受け取り、会話文（message）と予定・タスクの提案に分けて扱う。
struct GeminiService {
    /// 既定のモデル。提供モデルは入れ替わるため、設定画面から変更できるようにしてある。
    static let defaultModel = "gemini-3.6-flash"

    private static let endpoint = "https://generativelanguage.googleapis.com/v1beta/models"

    enum ServiceError: LocalizedError {
        case missingAPIKey
        case missingModel
        case invalidResponse
        case api(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "APIキーが設定されていません。"
            case .missingModel:
                return "モデル名が設定されていません。"
            case .invalidResponse:
                return "応答を解析できませんでした。"
            case .api(let message):
                return message
            }
        }
    }

    // MARK: - リクエスト / レスポンスの型

    private struct RequestBody: Encodable {
        let systemInstruction: Content
        let contents: [Content]
        let generationConfig: GenerationConfig
    }

    private struct GenerationConfig: Encodable {
        let responseMimeType: String
    }

    private struct Content: Codable {
        var role: String?
        let parts: [Part]
    }

    /// テキストか画像のどちらかを持つ。nil のフィールドは JSON に出力されない。
    private struct Part: Codable {
        var text: String?
        var inlineData: InlineData?
    }

    private struct InlineData: Codable {
        let mimeType: String
        /// 画像を Base64 にしたもの
        let data: String
    }

    private struct ResponseBody: Decodable {
        struct Candidate: Decodable {
            let content: ResponseContent?
        }
        struct ResponseContent: Decodable {
            let parts: [ResponsePart]?
        }
        struct ResponsePart: Decodable {
            let text: String?
        }
        struct APIError: Decodable {
            let message: String
        }

        let candidates: [Candidate]?
        let error: APIError?
    }

    // MARK: - 呼び出し

    /// これまでの会話（添付画像を含む）を送信し、会話文と提案を返す
    static func send(history: [ChatMessage],
                     existingEvents: [Event],
                     apiKey: String,
                     model: String) async throws -> GeminiReply {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw ServiceError.missingAPIKey }

        let modelName = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelName.isEmpty else { throw ServiceError.missingModel }

        guard let url = URL(string: "\(endpoint)/\(modelName):generateContent") else {
            throw ServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // キーは URL ではなくヘッダーで渡す（ログや履歴に残さないため）
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")

        let contents = history.compactMap { message -> Content? in
            let parts = parts(for: message)
            guard !parts.isEmpty else { return nil }
            return Content(role: message.isUser ? "user" : "model", parts: parts)
        }

        let body = RequestBody(
            systemInstruction: Content(parts: [Part(text: systemInstruction(existingEvents: existingEvents))]),
            contents: contents,
            generationConfig: GenerationConfig(responseMimeType: "application/json")
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)

        if let error = decoded.error {
            throw ServiceError.api(error.message)
        }

        // 応答が複数パートに分かれることがあるので連結する
        let text = decoded.candidates?.first?.content?.parts?
            .compactMap(\.text)
            .joined()

        guard let text, !text.isEmpty else { throw ServiceError.invalidResponse }
        return try reply(from: text)
    }

    /// JSON 文字列を GeminiReply にする。JSON として読めない場合は本文として扱う。
    private static func reply(from text: String) throws -> GeminiReply {
        let cleaned = stripCodeFence(text)

        guard let data = cleaned.data(using: .utf8) else { throw ServiceError.invalidResponse }
        if let reply = try? JSONDecoder().decode(GeminiReply.self, from: data) {
            return reply
        }

        // JSON で返ってこなかった場合でも会話は成立させる
        return GeminiReply(message: text, events: nil, tasks: nil)
    }

    /// ```json ... ``` で囲まれていた場合に中身を取り出す
    private static func stripCodeFence(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }

        // 先頭の ``` と、続く言語名の行を落とす
        if let firstNewline = trimmed.firstIndex(of: "\n") {
            trimmed = String(trimmed[trimmed.index(after: firstNewline)...])
        }
        if let fenceRange = trimmed.range(of: "```", options: .backwards) {
            trimmed = String(trimmed[..<fenceRange.lowerBound])
        }
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 1 件のメッセージを API のパート配列に変換する（画像 → テキストの順）
    private static func parts(for message: ChatMessage) -> [Part] {
        var parts: [Part] = []

        if let imageData = message.imageData {
            parts.append(Part(inlineData: InlineData(mimeType: "image/jpeg",
                                                     data: imageData.base64EncodedString())))
        }

        let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            parts.append(Part(text: message.text))
        }

        return parts
    }

    // MARK: - システムプロンプト

    /// 予定・タスクを提案させるための指示。現在日時と既存の予定を毎回渡して、
    /// 空き時間を踏まえた提案ができるようにする。
    private static func systemInstruction(existingEvents: [Event]) -> String {
        let now = Date()
        let nowText = PlanDateParser.string(from: now)
        let weekday = now.formatted(.dateTime.weekday(.wide).locale(.app))
        let categories = EventCategory.allCases
            .map { "\($0.rawValue)（\($0.title): \($0.detail)）" }
            .joined(separator: "\n          - ")

        return """
        あなたは「\(Slacker.name)」という名前の、日本語で応答するスケジュール管理アシスタントです。\
        ユーザーの予定やタスクの相談を受け、カレンダーに登録する予定と、やることリストに登録するタスクを提案します。

        # 現在の状況
        - 現在日時: \(nowText)（\(weekday)）
        - タイムゾーン: \(TimeZone.current.identifier)

        # ユーザーの既存の予定（今後2週間）
        \(existingEventsText(existingEvents))

        # 応答の形式
        必ず次の構造の JSON だけを返してください。前後に説明文やコードフェンスを付けないこと。

        {
          "message": "ユーザーへの返答文（日本語）",
          "events": [
            {
              "title": "予定名",
              "location": "場所（不明なら空文字）",
              "start": "yyyy-MM-dd'T'HH:mm",
              "end": "yyyy-MM-dd'T'HH:mm",
              "isAllDay": false,
              "category": "種類",
              "reason": "この日時にした理由（1文）"
            }
          ],
          "tasks": [
            {
              "title": "タスク名",
              "dueDate": "yyyy-MM-dd",
              "category": "種類",
              "reason": "この期限にした理由（1文）"
            }
          ]
        }

        # ルール
        - 日時はタイムゾーン表記を付けず、上の形式のローカル時刻で書くこと。
        - category は予定・タスクの性質から判断し、次のいずれかの値を必ず指定すること。
          - \(categories)
        - 締め切り・提出物・作業枠は assignment、遊びや趣味の予定は leisure、
          授業・勤務・通学など決まった時間の予定は routine を選ぶこと。
        - 締め切りのある予定を相談されたら、次の3つをまとめて提案すること。
          1. 締め切り自体を events に入れる（締め切り時刻の予定として）
          2. 同じ内容を tasks にも入れる（dueDate は締め切り日）
          3. 既存の予定と重ならない空き時間に、作業用の枠を events に入れる（特に指定がなければ2時間、締め切りより前）
        - 作業枠は 8:00〜22:00 の間に置き、既存の予定と時間が重ならないようにすること。
        - 情報が足りないときは提案せず、message で質問すること（events と tasks は空配列）。
        - 予定と関係のない雑談や質問には、events と tasks を空配列にして message だけで答えること。
        - 提案したときは message の最後に、承認を求める一文を添えること。
        - ユーザーから修正の指示が来たら、直前の提案を修正した内容を改めて提案し直すこと。
        """
    }

    private static func existingEventsText(_ events: [Event]) -> String {
        let calendar = Calendar.current
        let now = Date()
        guard let limit = calendar.date(byAdding: .day, value: 14, to: now) else { return "（なし）" }

        let upcoming = events
            .filter { $0.end >= calendar.startOfDay(for: now) && $0.start <= limit }
            .sorted { $0.start < $1.start }

        guard !upcoming.isEmpty else { return "（登録されている予定はありません）" }

        return upcoming.map { event in
            let start = PlanDateParser.string(from: event.start)
            let end = PlanDateParser.string(from: event.end)
            let allDay = event.isAllDay ? "（終日）" : ""
            let location = event.location.isEmpty ? "" : " @\(event.location)"
            return "- \(event.title)\(allDay): \(start) 〜 \(end)\(location)"
        }.joined(separator: "\n")
    }
}
