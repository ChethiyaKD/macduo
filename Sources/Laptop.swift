import Foundation

enum Laptop {
    static let ssh = "/usr/bin/ssh"

    private static func remote(_ config: LaptopConfig, _ command: String, timeout: TimeInterval = 15) async -> ShellResult {
        await Shell.run(ssh, [
            "-n", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5",
            "\(config.user)@\(config.host)", command,
        ], timeout: timeout)
    }

    static func startStream(_ config: LaptopConfig, macHost: String, resolution: Resolution) async -> ShellResult {
        await remote(config, "~/.local/bin/screenshare-start \(macHost) \(resolution.rawValue) \(config.fps) \(config.bitrateKbps)")
    }

    /// First laptop address that answers on SSH.
    static func reachableHost(_ config: LaptopConfig) async -> String? {
        for host in config.hosts {
            let probe = await Shell.run("/usr/bin/nc", ["-z", "-G", "2", host, "22"], timeout: 4)
            if probe.ok { return host }
        }
        return nil
    }

    static func stopStream(_ config: LaptopConfig) async {
        await remote(config, "~/.local/bin/screenshare-stop", timeout: 8)
    }

    /// This Mac's IPv4 address on the same /24 as the laptop.
    static func macAddress(near host: String) -> String? {
        let prefix = host.split(separator: ".").prefix(3).joined(separator: ".") + "."
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard let addr = pointer.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(addr, socklen_t(addr.pointee.sa_len), &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST)
            let ip = String(cString: buffer)
            if ip.hasPrefix(prefix) { return ip }
        }
        return nil
    }
}
