import Foundation

/// codex-reset.com 的全球额度重置预测。该预测不替代个人 5 小时/周度窗口。
enum CodexResetForecastClient {
    private struct Payload: Decodable {
        struct Probabilities: Decodable {
            var rounded24h: Int
            var rounded48h: Int

            enum CodingKeys: String, CodingKey {
                case rounded24h = "rounded_24h"
                case rounded48h = "rounded_48h"
            }
        }

        struct TimeWindow: Decodable {
            var label: String
            var timezone: String
        }

        var updatedAt: Date
        var probabilities: Probabilities
        var confidence: String
        var lastResetAt: Date?
        var timeWindow: TimeWindow?

        enum CodingKeys: String, CodingKey {
            case updatedAt = "updated_at"
            case probabilities
            case confidence
            case lastResetAt = "last_reset_at"
            case timeWindow = "time_window"
        }
    }

    static func fetch() async throws -> CodexResetForecast {
        var request = URLRequest(url: URL(string: "https://codex-reset.com/api/forecast")!)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { input in
            let value = try input.singleValueContainer().decode(String.self)
            guard let date = Fmt.parseISO(value) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: input.codingPath, debugDescription: "bad date \(value)")
                )
            }
            return date
        }
        let payload = try decoder.decode(Payload.self, from: data)
        let likelyWindow = payload.timeWindow.map { "\($0.label) \($0.timezone)" }
        return CodexResetForecast(
            updatedAt: payload.updatedAt,
            probability24h: payload.probabilities.rounded24h,
            probability48h: payload.probabilities.rounded48h,
            confidence: payload.confidence,
            lastResetAt: payload.lastResetAt,
            likelyWindow: likelyWindow
        )
    }
}
