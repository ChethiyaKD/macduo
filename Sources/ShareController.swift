import Foundation
import ServiceManagement

@MainActor
final class ShareController: ObservableObject {
    enum State: Equatable {
        case off, starting, waiting, connected, stopping
        case failed(String)
    }

    @Published private(set) var state: State = .off
    @Published private(set) var step = ""

    @Published var resolution: Resolution {
        didSet {
            defaults.set(resolution.rawValue, forKey: "resolution")
            if isSharing { Task { await applyResolution() } }
        }
    }

    @Published var side: Side {
        didSet {
            defaults.set(side.rawValue, forKey: "side")
            if isSharing { VirtualScreen.place(side: side) }
        }
    }

    @Published var startLaptop: Bool {
        didSet { defaults.set(startLaptop, forKey: "startLaptop") }
    }

    @Published var pauseAirDrop: Bool {
        didSet {
            defaults.set(pauseAirDrop, forKey: "pauseAirDrop")
            guard isSharing else { return }
            Task { pauseAirDrop ? await AirDrop.pause() : await AirDrop.restore() }
        }
    }

    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var laptop = LaptopConfig()
    private let defaults = UserDefaults.standard
    private var busy = false
    private var poller: Task<Void, Never>?
    private var hotKey: HotKey?

    init() {
        resolution = Resolution(rawValue: defaults.string(forKey: "resolution") ?? "") ?? .p1080
        side = Side(rawValue: defaults.string(forKey: "side") ?? "") ?? .left
        startLaptop = defaults.object(forKey: "startLaptop") as? Bool ?? true
        pauseAirDrop = defaults.object(forKey: "pauseAirDrop") as? Bool ?? true
        hotKey = HotKey { [weak self] in Task { @MainActor in self?.toggle() } }
        Task { await detectRunningSession() }
    }

    var isSharing: Bool {
        switch state {
        case .starting, .waiting, .connected: return true
        default: return false
        }
    }

    var statusText: String {
        switch state {
        case .off: return "Not sharing"
        case .starting: return step.isEmpty ? "Starting…" : step
        case .waiting: return "Sharing: waiting for laptop"
        case .connected: return "Sharing: laptop connected"
        case .stopping: return "Stopping…"
        case .failed(let message): return "Error: \(message)"
        }
    }

    var menuBarSymbol: String {
        switch state {
        case .off: return "display"
        case .starting, .stopping: return "hourglass"
        case .waiting: return "display.2"
        case .connected: return "rectangle.on.rectangle.circle.fill"
        case .failed: return "exclamationmark.triangle"
        }
    }

    func toggle() {
        guard !busy else { return }
        Task { isSharing ? await stop() : await start() }
    }

    func start() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        state = .starting

        if pauseAirDrop { await AirDrop.pause() }

        step = "Opening BetterDisplay…"
        guard await VirtualScreen.ensureBetterDisplayRunning() else {
            return fail("BetterDisplay didn't respond")
        }

        step = "Adding the virtual screen…"
        guard await VirtualScreen.connect(resolution: resolution), let id = VirtualScreen.displayID() else {
            return fail("virtual screen didn't appear")
        }
        VirtualScreen.place(side: side)

        step = "Starting Sunshine…"
        Sunshine.setOutputDisplay(id)
        guard await Sunshine.restart() else {
            return fail("Sunshine didn't start")
        }

        if startLaptop {
            step = "Starting Moonlight on the laptop…"
            if let failure = await startLaptopStream() { return fail(failure) }
        }

        step = ""
        state = Sunshine.clientConnected() ? .connected : .waiting
        startPolling()
    }

    func stop() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        poller?.cancel()
        state = .stopping
        await Laptop.stopStream(laptop)
        await Sunshine.stop()
        await VirtualScreen.disconnect()
        await AirDrop.restore()
        state = .off
    }

    func reconnectLaptop() {
        guard isSharing, !busy else { return }
        Task {
            busy = true
            defer { busy = false }
            if let failure = await startLaptopStream() { state = .failed(failure) }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Launch at login change failed: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func startLaptopStream() async -> String? {
        guard let host = await Laptop.reachableHost(laptop) else {
            return "laptop is off or not on the network"
        }
        laptop.host = host
        guard let macHost = Laptop.macAddress(near: laptop.host) else {
            return "Mac isn't on the laptop's network"
        }
        let result = await Laptop.startStream(laptop, macHost: macHost, resolution: resolution)
        return result.ok ? nil : "can't reach the laptop over SSH"
    }

    private func applyResolution() async {
        await VirtualScreen.setResolution(resolution)
        VirtualScreen.place(side: side)
        if startLaptop || state == .connected {
            _ = await startLaptopStream()
        }
    }

    private func fail(_ message: String) {
        step = ""
        Task { await AirDrop.restore() }
        state = .failed(message)
    }

    private func startPolling() {
        poller?.cancel()
        poller = Task { [weak self] in
            while !Task.isCancelled {
                await Shell.sleep(2)
                guard let self, !self.busy else { continue }
                guard self.state == .waiting || self.state == .connected else { continue }
                self.state = Sunshine.clientConnected() ? .connected : .waiting
            }
        }
    }

    private func detectRunningSession() async {
        guard VirtualScreen.displayID() != nil, await Sunshine.isRunning() else { return }
        state = Sunshine.clientConnected() ? .connected : .waiting
        startPolling()
    }
}
