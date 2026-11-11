import Foundation

enum Resolution: String, CaseIterable, Identifiable {
    case p1080 = "1920x1080"
    case p900 = "1600x900"
    case p720 = "1280x720"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .p1080: return "1080p (1920×1080)"
        case .p900: return "900p (1600×900)"
        case .p720: return "720p (1280×720)"
        }
    }
}

enum Side: String, CaseIterable, Identifiable {
    case left, right, top, bottom

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct LaptopConfig {
    /// Wired adapter first, Wi-Fi as fallback.
    var hosts = ["192.168.1.120", "192.168.1.231"]
    var host = "192.168.1.120"
    var user = "roach"
    var fps = 60
    var bitrateKbps = 10000
}
