import Foundation
import Network

enum Sunshine {
    static let brew = "/opt/homebrew/bin/brew"
    static let formula = "lizardbyte/homebrew/sunshine"
    static let configURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/sunshine/sunshine.conf")
    static let logURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/sunshine/sunshine.log")

    static func setOutputDisplay(_ id: UInt32) {
        let text = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        lines.removeAll { $0.hasPrefix("output_name") }
        while lines.last == "" { lines.removeLast() }
        lines.append("output_name = \(id)")
        try? (lines.joined(separator: "\n") + "\n").write(to: configURL, atomically: true, encoding: .utf8)
    }

    static func restart() async -> Bool {
        await Shell.run(brew, ["services", "restart", formula], timeout: 60)
        for _ in 0..<30 {
            if await isListening() { return true }
            await Shell.sleep(0.5)
        }
        return false
    }

    static func stop() async {
        await Shell.run(brew, ["services", "stop", formula], timeout: 60)
    }

    static func isRunning() async -> Bool {
        await Shell.run("/usr/bin/pgrep", ["-x", "sunshine"], timeout: 3).ok
    }

    static func isListening() async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(host: "127.0.0.1", port: 47989, using: .tcp)
            var finished = false
            let finish: (Bool) -> Void = { value in
                guard !finished else { return }
                finished = true
                connection.cancel()
                continuation.resume(returning: value)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: finish(true)
                case .failed, .waiting: finish(false)
                default: break
                }
            }
            let queue = DispatchQueue(label: "sunshine.probe")
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 1) { finish(false) }
        }
    }

    /// Whether a Moonlight client is connected, from the last connect/disconnect line in the log.
    static func clientConnected() -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: logURL) else { return false }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: size > 65_536 ? size - 65_536 : 0)
        let tail = String(decoding: handle.readDataToEndOfFile(), as: UTF8.self)
        let connected = tail.range(of: "CLIENT CONNECTED", options: .backwards)
        let disconnected = tail.range(of: "CLIENT DISCONNECTED", options: .backwards)
        switch (connected, disconnected) {
        case (nil, _): return false
        case (_?, nil): return true
        case let (c?, d?): return c.lowerBound > d.lowerBound
        }
    }
}
