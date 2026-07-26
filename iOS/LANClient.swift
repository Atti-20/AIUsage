import Foundation
import Network

/// iOS 端局域网客户端：Bonjour 自动发现 Mac 上的快照服务并拉取 JSON；
/// 也支持手动填写 "主机名.local:48764" 直连。
enum LANClient {
    static let serviceType = "_aiusage._tcp"
    static let defaultPort: UInt16 = 48764

    // MARK: 手动地址（走 URLSession，需 Info.plist 允许本地明文）

    static func fetch(manualAddress: String) async throws -> UsageSnapshot {
        var address = manualAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !address.contains(":") { address += ":\(defaultPort)" }
        guard let url = URL(string: "http://\(address)/snapshot.json") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        let (data, _) = try await URLSession.shared.data(for: request)
        return try SyncStore.decoder.decode(UsageSnapshot.self, from: data)
    }

    // MARK: 自动发现

    static func discoverAndFetch() async throws -> UsageSnapshot {
        let endpoint = try await discover(timeout: 4)
        let body = try await httpGET(endpoint: endpoint)
        return try SyncStore.decoder.decode(UsageSnapshot.self, from: body)
    }

    private final class OnceFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func tryComplete() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if done { return false }
            done = true
            return true
        }
    }

    private static func discover(timeout: TimeInterval) async throws -> NWEndpoint {
        try await withCheckedThrowingContinuation { cont in
            let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: .tcp)
            let flag = OnceFlag()
            browser.browseResultsChangedHandler = { results, _ in
                guard let first = results.first, flag.tryComplete() else { return }
                browser.cancel()
                cont.resume(returning: first.endpoint)
            }
            browser.stateUpdateHandler = { state in
                if case .failed(let error) = state, flag.tryComplete() {
                    browser.cancel()
                    cont.resume(throwing: error)
                }
            }
            browser.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if flag.tryComplete() {
                    browser.cancel()
                    cont.resume(throwing: URLError(.timedOut))
                }
            }
        }
    }

    /// 直接对 Bonjour endpoint 发起最简 HTTP GET（免去地址解析）。
    private static func httpGET(endpoint: NWEndpoint) async throws -> Data {
        try await withCheckedThrowingContinuation { cont in
            let conn = NWConnection(to: endpoint, using: .tcp)
            let flag = OnceFlag()
            let buffer = BufferBox()

            func fail(_ error: Error) {
                if flag.tryComplete() {
                    conn.cancel()
                    cont.resume(throwing: error)
                }
            }

            func receiveLoop() {
                conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 21) { data, _, isComplete, error in
                    if let data { buffer.append(data) }
                    if let error {
                        fail(error)
                        return
                    }
                    if isComplete {
                        guard flag.tryComplete() else { return }
                        conn.cancel()
                        let all = buffer.data
                        if let range = all.range(of: Data("\r\n\r\n".utf8)) {
                            cont.resume(returning: all.subdata(in: range.upperBound..<all.endIndex))
                        } else {
                            cont.resume(throwing: URLError(.badServerResponse))
                        }
                    } else {
                        receiveLoop()
                    }
                }
            }

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let request = "GET /snapshot.json HTTP/1.1\r\nHost: aiusage\r\nConnection: close\r\n\r\n"
                    conn.send(content: Data(request.utf8), completion: .contentProcessed { error in
                        if let error { fail(error) }
                    })
                    receiveLoop()
                case .failed(let error):
                    fail(error)
                default:
                    break
                }
            }
            conn.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                fail(URLError(.timedOut))
            }
        }
    }

    private final class BufferBox: @unchecked Sendable {
        private let lock = NSLock()
        private var storage = Data()
        var data: Data {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
        func append(_ d: Data) {
            lock.lock()
            storage.append(d)
            lock.unlock()
        }
    }
}
