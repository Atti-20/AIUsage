import Foundation
import Network

/// Mac 端内置的只读迷你 HTTP 服务：把最新的 UsageSnapshot JSON
/// 提供给同一局域网内的 iPhone（Bonjour `_aiusage._tcp` 自动发现）。
/// 只监听、只返回汇总数据，不接受任何写入。
final class SnapshotServer: @unchecked Sendable {
    static let shared = SnapshotServer()
    static let port: UInt16 = 48764
    static let serviceType = "_aiusage._tcp"

    static let discoveryPort: UInt16 = 48765

    private let lock = NSLock()
    private var listener: NWListener?
    private var udpListener: NWListener?
    private var payload = Data("{}".utf8)
    private var running = false

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    /// iPhone 手动填写时用的地址。
    static var manualAddress: String {
        "\(ProcessInfo.processInfo.hostName):\(port)"
    }

    func update(_ data: Data) {
        lock.lock()
        payload = data
        lock.unlock()
    }

    func start() {
        lock.lock()
        let alreadyStarted = listener != nil
        lock.unlock()
        guard !alreadyStarted else { return }

        guard let port = NWEndpoint.Port(rawValue: Self.port),
              let l = try? NWListener(using: .tcp, on: port) else { return }
        l.service = NWListener.Service(name: Host.current().localizedName ?? "Mac",
                                       type: Self.serviceType)
        l.newConnectionHandler = { [weak self] conn in
            self?.handle(conn)
        }
        l.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            self.lock.lock()
            switch state {
            case .ready:
                self.running = true
            case .failed, .cancelled:
                // 绑定失败（如端口被占）时清理，下次 refresh 会自动重试
                self.running = false
                self.listener?.cancel()
                self.listener = nil
            default:
                self.running = false
            }
            self.lock.unlock()
        }
        lock.lock()
        listener = l
        lock.unlock()
        l.start(queue: .global(qos: .utility))
        startUDPResponder()
    }

    /// UDP 发现应答：Android/Windows 客户端向 48765 广播 "AIUSAGE_DISCOVER"，
    /// 收到 "AIUSAGE <主机名> <端口>" 即可定位本机（Bonjour 之外的兜底）。
    private func startUDPResponder() {
        lock.lock()
        let exists = udpListener != nil
        lock.unlock()
        guard !exists,
              let port = NWEndpoint.Port(rawValue: Self.discoveryPort),
              let l = try? NWListener(using: .udp, on: port) else { return }
        l.newConnectionHandler = { conn in
            conn.start(queue: .global(qos: .utility))
            conn.receiveMessage { data, _, _, _ in
                guard let data, String(data: data, encoding: .utf8)?.hasPrefix("AIUSAGE_DISCOVER") == true else {
                    conn.cancel()
                    return
                }
                let reply = "AIUSAGE \(ProcessInfo.processInfo.hostName) \(Self.port)"
                conn.send(content: Data(reply.utf8), completion: .contentProcessed { _ in
                    conn.cancel()
                })
            }
        }
        l.stateUpdateHandler = { [weak self] state in
            if case .failed = state {
                guard let self else { return }
                self.lock.lock()
                self.udpListener?.cancel()
                self.udpListener = nil
                self.lock.unlock()
            }
        }
        lock.lock()
        udpListener = l
        lock.unlock()
        l.start(queue: .global(qos: .utility))
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: .global(qos: .utility))
        // 读掉请求头后统一返回快照 JSON（无论请求路径）
        conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] _, _, _, _ in
            guard let self else {
                conn.cancel()
                return
            }
            self.lock.lock()
            let body = self.payload
            self.lock.unlock()
            var response = Data("""
            HTTP/1.1 200 OK\r
            Content-Type: application/json; charset=utf-8\r
            Content-Length: \(body.count)\r
            Connection: close\r
            \r

            """.utf8)
            response.append(body)
            conn.send(content: response, completion: .contentProcessed { _ in
                conn.cancel()
            })
        }
    }
}
