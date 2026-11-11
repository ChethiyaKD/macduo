import Foundation

/// AirDrop's radio (AWDL) causes Wi-Fi latency spikes, so receiving is paused while sharing.
enum AirDrop {
    private static let domain = "com.apple.sharingd"
    private static let key = "DiscoverableMode"
    private static let savedKey = "airDropModeBeforeSharing"

    static func pause() async {
        let current = await mode()
        if current != "Off" {
            UserDefaults.standard.set(current, forKey: savedKey)
        }
        await setMode("Off")
    }

    static func restore() async {
        guard let saved = UserDefaults.standard.string(forKey: savedKey) else { return }
        await setMode(saved)
        UserDefaults.standard.removeObject(forKey: savedKey)
    }

    private static func mode() async -> String {
        let result = await Shell.run("/usr/bin/defaults", ["read", domain, key], timeout: 5)
        return result.ok ? result.output : "Contacts Only"
    }

    private static func setMode(_ mode: String) async {
        await Shell.run("/usr/bin/defaults", ["write", domain, key, "-string", mode], timeout: 5)
        await Shell.run("/usr/bin/killall", ["sharingd"], timeout: 5)
    }
}
