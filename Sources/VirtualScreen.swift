import AppKit
import CoreGraphics

enum VirtualScreen {
    static let cli = "/opt/homebrew/bin/betterdisplaycli"
    static let name = "LaptopScreen"
    static let bundleID = "pro.betterdisplay.BetterDisplay"

    static func ensureBetterDisplayRunning() async -> Bool {
        if await respond() { return true }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: config)
        }
        for _ in 0..<20 {
            if await respond() { return true }
            await Shell.sleep(0.5)
        }
        return false
    }

    private static func respond() async -> Bool {
        let result = await Shell.run(cli, ["get", "-name=\(name)", "-connected"], timeout: 3)
        return result.ok && !result.output.contains("Failed")
    }

    static func isConnected() async -> Bool {
        let result = await Shell.run(cli, ["get", "-name=\(name)", "-connected"], timeout: 5)
        return result.output.hasPrefix("on")
    }

    static func connect(resolution: Resolution) async -> Bool {
        await Shell.run(cli, ["set", "-name=\(name)", "-connected=on"])
        for _ in 0..<20 {
            if displayID() != nil { break }
            await Shell.sleep(0.25)
        }
        guard displayID() != nil else { return false }
        await setResolution(resolution)
        return true
    }

    static func setResolution(_ resolution: Resolution) async {
        await Shell.run(cli, ["set", "-name=\(name)", "-resolution=\(resolution.rawValue)"])
    }

    static func disconnect() async {
        await Shell.run(cli, ["set", "-name=\(name)", "-connected=off"])
    }

    /// The virtual screen's CoreGraphics ID, found by its fixed vendor/model/serial.
    static func displayID() -> CGDirectDisplayID? {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)
        return ids.first {
            CGDisplayVendorNumber($0) == 2198 && CGDisplayModelNumber($0) == 44245
                && CGDisplaySerialNumber($0) == 1_605_203_009
        }
    }

    static func place(side: Side) {
        guard let id = displayID() else { return }
        let main = CGMainDisplayID()
        guard main != id else { return }
        let m = CGDisplayBounds(main)
        let v = CGDisplayBounds(id)
        let x: CGFloat
        let y: CGFloat
        switch side {
        case .left:
            x = m.minX - v.width
            y = m.minY + (m.height - v.height) / 2
        case .right:
            x = m.maxX
            y = m.minY + (m.height - v.height) / 2
        case .top:
            x = m.minX + (m.width - v.width) / 2
            y = m.minY - v.height
        case .bottom:
            x = m.minX + (m.width - v.width) / 2
            y = m.maxY
        }
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return }
        CGConfigureDisplayOrigin(config, id, Int32(x.rounded()), Int32(y.rounded()))
        CGCompleteDisplayConfiguration(config, .permanently)
    }
}
