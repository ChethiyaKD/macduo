import SwiftUI

@main
struct ScreenShareApp: App {
    @StateObject private var controller = ShareController()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(controller: controller)
        } label: {
            Image(systemName: controller.menuBarSymbol)
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuContent: View {
    @ObservedObject var controller: ShareController

    var body: some View {
        Text(controller.statusText)

        Divider()

        switch controller.state {
        case .starting, .stopping:
            Button("Working…") {}.disabled(true)
        default:
            Button(controller.isSharing ? "Stop Sharing" : "Start Sharing") { controller.toggle() }
                .keyboardShortcut("d", modifiers: [.control, .option, .command])
        }

        if controller.isSharing {
            Button("Reconnect Laptop") { controller.reconnectLaptop() }
        }

        Divider()

        Picker("Resolution", selection: $controller.resolution) {
            ForEach(Resolution.allCases) { Text($0.label).tag($0) }
        }

        Picker("Laptop Position", selection: $controller.side) {
            ForEach(Side.allCases) { Text($0.label).tag($0) }
        }

        Toggle("Start Moonlight on Laptop", isOn: $controller.startLaptop)

        Toggle("Pause AirDrop While Sharing", isOn: $controller.pauseAirDrop)

        Toggle("Launch at Login", isOn: Binding(
            get: { controller.launchAtLogin },
            set: { controller.setLaunchAtLogin($0) }
        ))

        Divider()

        Text("Shortcut: \(HotKey.displayString)")

        Button("Quit ScreenShare") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
