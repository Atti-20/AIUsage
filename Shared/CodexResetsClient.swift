import Foundation

/// codex-resets.com 数据源：追踪 OpenAI 产品经理 @thsottiaux
/// 公布的 Codex / ChatGPT 用量限额重置公告。
enum CodexResetsClient {
    private struct Payload: Codable {
        var events: [ResetEvent]
    }

    static func fetch() async throws -> [ResetEvent] {
        var request = URLRequest(url: URL(string: "https://codex-resets.com/api/resets")!)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let s = try d.singleValueContainer().decode(String.self)
            guard let date = Fmt.parseISO(s) else {
                throw DecodingError.dataCorrupted(.init(codingPath: d.codingPath, debugDescription: "bad date \(s)"))
            }
            return date
        }
        return try decoder.decode(Payload.self, from: data)
            .events
            .sorted { $0.announcedAt > $1.announcedAt }
    }
}
