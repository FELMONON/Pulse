import SwiftUI
import ServiceManagement
import WidgetKit
#if os(macOS)
import AppKit
#endif

@main
struct MacMonitorApp: App {
    @StateObject private var statsController = PulseStatsController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(statsController)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 420, height: 480)

        Window("Settings", id: PulseSettings.settingsWindowID) {
            PulseSettingsView()
                .environmentObject(statsController)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 420, height: 400)
        .windowResizability(.contentSize)

        MenuBarExtra {
            PulseMenuBarMenu(statsController: statsController)
        } label: {
            PulseMenuBarLabel(statsController: statsController)
        }
        .menuBarExtraStyle(.menu)
    }
}

// MARK: - App Settings
enum PulseSettings {
    static let settingsWindowID = "pulse-settings"
    static let defaults = PulseSharedSettings.defaults
    static let defaultRefreshInterval = PulseSharedSettings.defaultRefreshInterval
    static let refreshIntervals = PulseSharedSettings.refreshIntervals
    typealias Keys = PulseSharedSettings.Keys
    typealias UnitsMode = PulseSharedSettings.UnitsMode

    static var storedRefreshInterval: TimeInterval { PulseSharedSettings.storedRefreshInterval }
    static func clampedRefreshInterval(_ value: TimeInterval) -> TimeInterval { PulseSharedSettings.clampedRefreshInterval(value) }
    static func intervalLabel(_ interval: TimeInterval) -> String { PulseSharedSettings.intervalLabel(interval) }
    static func percent(_ value: Double) -> String { PulseSharedSettings.percent(value) }
    static func formatSpeed(_ speed: Double, unitsMode: UnitsMode) -> String { PulseSharedSettings.formatSpeed(speed, unitsMode: unitsMode) }
}

// MARK: - Launch at Login
enum LaunchAtLoginService {
    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    static var isOnOrPendingApproval: Bool {
        switch status {
        case .enabled, .requiresApproval:
            return true
        case .notRegistered, .notFound:
            return false
        @unknown default:
            return false
        }
    }

    static var statusText: String {
        switch status {
        case .enabled:
            return "Enabled"
        case .requiresApproval:
            return "Requires approval in System Settings"
        case .notRegistered:
            return "Off"
        case .notFound:
            return "Unavailable for this build"
        @unknown default:
            return "Unknown"
        }
    }

    static func setEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            switch status {
            case .enabled, .requiresApproval:
                return
            case .notRegistered, .notFound:
                try SMAppService.mainApp.register()
            @unknown default:
                try SMAppService.mainApp.register()
            }
        } else {
            switch status {
            case .enabled, .requiresApproval:
                try SMAppService.mainApp.unregister()
            case .notRegistered, .notFound:
                return
            @unknown default:
                try SMAppService.mainApp.unregister()
            }
        }
    }
}

// MARK: - Shared App Stats
@MainActor
final class PulseStatsController: ObservableObject {
    @Published private(set) var stats: SystemStats

    private var timer: Timer?
    private var refreshInterval: TimeInterval = PulseSettings.storedRefreshInterval
    private var lastWidgetTimelineReload = Date.distantPast
    private let widgetTimelineReloadInterval: TimeInterval = 15

    init() {
        stats = SystemMonitor.shared.getCachedStats(maxAge: 120) ?? .placeholder
        configureTimer(interval: refreshInterval)
        refresh(reloadWidgets: true)
    }

    deinit {
        timer?.invalidate()
    }

    func refresh(reloadWidgets: Bool = false) {
        stats = SystemMonitor.shared.getStatsAndCache()
        reloadWidgetTimelineIfNeeded(force: reloadWidgets)
    }

    func updateRefreshInterval(_ newInterval: TimeInterval) {
        let clampedInterval = PulseSettings.clampedRefreshInterval(newInterval)
        guard clampedInterval != refreshInterval else {
            return
        }

        refreshInterval = clampedInterval
        configureTimer(interval: clampedInterval)
    }

    private func configureTimer(interval: TimeInterval) {
        timer?.invalidate()

        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        timer.tolerance = min(max(interval * 0.1, 0.1), 2)
        self.timer = timer
    }

    private func reloadWidgetTimelineIfNeeded(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastWidgetTimelineReload) >= widgetTimelineReloadInterval else {
            return
        }

        lastWidgetTimelineReload = now
        WidgetCenter.shared.reloadTimelines(ofKind: "MacMonitorWidget")
    }
}

// MARK: - Menu Bar
struct PulseMenuBarLabel: View {
    @ObservedObject var statsController: PulseStatsController

    private var stats: SystemStats {
        statsController.stats
    }

    var body: some View {
        Label {
            Text("CPU \(PulseSettings.percent(stats.cpuUsage)) RAM \(PulseSettings.percent(stats.memoryUsage))")
        } icon: {
            Image(systemName: "gauge.with.dots.needle.50percent")
        }
    }
}

struct PulseMenuBarMenu: View {
    @ObservedObject var statsController: PulseStatsController
    @AppStorage(PulseSettings.Keys.unitsMode, store: PulseSettings.defaults) private var unitsModeRaw = PulseSettings.UnitsMode.automatic.rawValue
    @AppStorage(PulseSettings.Keys.showBattery, store: PulseSettings.defaults) private var showBattery = true
    @AppStorage(PulseSettings.Keys.showDisk, store: PulseSettings.defaults) private var showDisk = true
    @AppStorage(PulseSettings.Keys.showNetwork, store: PulseSettings.defaults) private var showNetwork = true
    @AppStorage(PulseSettings.Keys.showActiveApps, store: PulseSettings.defaults) private var showActiveApps = true

    private var stats: SystemStats {
        statsController.stats
    }

    private var unitsMode: PulseSettings.UnitsMode {
        PulseSettings.UnitsMode(rawValue: unitsModeRaw) ?? .automatic
    }

    var body: some View {
        Text("CPU \(PulseSettings.percent(stats.cpuUsage))   RAM \(PulseSettings.percent(stats.memoryUsage))")

        if showBattery {
            Text(batterySummary)
        }

        if showDisk {
            Text(String(format: "Disk %.0f GB free", stats.diskAvailable))
        }

        if showNetwork {
            Text("Network \(networkSummary)")
        }

        if showActiveApps, !stats.activeApps.isEmpty {
            Text("Active \(stats.activeApps.prefix(4).joined(separator: ", "))")
        }

        Divider()

        Button {
            statsController.refresh(reloadWidgets: true)
        } label: {
            Label("Refresh Stats", systemImage: "arrow.clockwise")
        }

        OpenSettingsMenuItem()

        Divider()

        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Quit Pulse", systemImage: "power")
        }
    }

    private var batterySummary: String {
        guard stats.hasBattery else {
            return "Battery AC"
        }

        let state = stats.isCharging ? "charging" : "remaining"
        return "Battery \(stats.batteryLevel)% \(state)"
    }

    private var networkSummary: String {
        let up = PulseSettings.formatSpeed(stats.networkUp, unitsMode: unitsMode)
        let down = PulseSettings.formatSpeed(stats.networkDown, unitsMode: unitsMode)
        return "Up \(up) Down \(down)"
    }
}

struct OpenSettingsMenuItem: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            openWindow(id: PulseSettings.settingsWindowID)
            NSApplication.shared.activate(ignoringOtherApps: true)
        } label: {
            Label("Open Settings", systemImage: "gearshape")
        }
    }
}

// MARK: - Settings Window
struct PulseSettingsView: View {
    @EnvironmentObject private var statsController: PulseStatsController

    @AppStorage(PulseSettings.Keys.launchAtLogin, store: PulseSettings.defaults) private var launchAtLoginPreference = false
    @AppStorage(PulseSettings.Keys.refreshInterval, store: PulseSettings.defaults) private var refreshInterval = PulseSettings.defaultRefreshInterval
    @AppStorage(PulseSettings.Keys.unitsMode, store: PulseSettings.defaults) private var unitsModeRaw = PulseSettings.UnitsMode.automatic.rawValue
    @AppStorage(PulseSettings.Keys.showBattery, store: PulseSettings.defaults) private var showBattery = true
    @AppStorage(PulseSettings.Keys.showDisk, store: PulseSettings.defaults) private var showDisk = true
    @AppStorage(PulseSettings.Keys.showNetwork, store: PulseSettings.defaults) private var showNetwork = true
    @AppStorage(PulseSettings.Keys.showActiveApps, store: PulseSettings.defaults) private var showActiveApps = true

    @State private var launchAtLoginEnabled = LaunchAtLoginService.isOnOrPendingApproval
    @State private var launchAtLoginStatusText = LaunchAtLoginService.statusText
    @State private var launchAtLoginError: String?

    private let metricColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                header

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Launch at Login", isOn: launchAtLoginBinding)
                        settingsStatusRow(launchAtLoginError ?? launchAtLoginStatusText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    SettingsSectionLabel(title: "Startup", systemImage: "power")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Refresh Interval")
                            Spacer()
                            Picker("Refresh Interval", selection: $refreshInterval) {
                                ForEach(PulseSettings.refreshIntervals, id: \.self) { interval in
                                    Text(PulseSettings.intervalLabel(interval)).tag(interval)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                        }

                        HStack {
                            Text("Units")
                            Spacer()
                            Picker("Units", selection: $unitsModeRaw) {
                                ForEach(PulseSettings.UnitsMode.allCases) { mode in
                                    Text(mode.title).tag(mode.rawValue)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        }
                    }
                } label: {
                    SettingsSectionLabel(title: "Display", systemImage: "slider.horizontal.3")
                }

                GroupBox {
                    LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 10) {
                        Toggle("Battery", isOn: $showBattery)
                        Toggle("Disk", isOn: $showDisk)
                        Toggle("Network", isOn: $showNetwork)
                        Toggle("Active Apps", isOn: $showActiveApps)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    SettingsSectionLabel(title: "Widget & Menu Metrics", systemImage: "menubar.rectangle")
                }
            }
            .padding(20)
        }
        .frame(width: 420)
        .onAppear {
            syncLaunchAtLoginState()
            statsController.updateRefreshInterval(refreshInterval)
        }
        .onChange(of: refreshInterval) { _, newValue in
            let clampedInterval = PulseSettings.clampedRefreshInterval(newValue)
            if clampedInterval != newValue {
                refreshInterval = clampedInterval
            }
            statsController.updateRefreshInterval(clampedInterval)
        }
        .onChange(of: unitsModeRaw) { _, _ in reloadWidgetsForSettingsChange() }
        .onChange(of: showBattery) { _, _ in reloadWidgetsForSettingsChange() }
        .onChange(of: showDisk) { _, _ in reloadWidgetsForSettingsChange() }
        .onChange(of: showNetwork) { _, _ in reloadWidgetsForSettingsChange() }
        .onChange(of: showActiveApps) { _, _ in reloadWidgetsForSettingsChange() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "gauge.with.dots.needle.50percent")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(AppColors.ramBlue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Pulse Settings")
                    .font(.system(size: 16, weight: .semibold))

                Text("Menu bar and startup")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding {
            launchAtLoginEnabled
        } set: { newValue in
            updateLaunchAtLogin(newValue)
        }
    }

    private func settingsStatusRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(launchAtLoginError == nil ? .secondary : .red)
    }

    private func syncLaunchAtLoginState() {
        launchAtLoginEnabled = LaunchAtLoginService.isOnOrPendingApproval
        launchAtLoginPreference = launchAtLoginEnabled
        launchAtLoginStatusText = LaunchAtLoginService.statusText
        launchAtLoginError = nil
    }

    private func updateLaunchAtLogin(_ isEnabled: Bool) {
        do {
            try LaunchAtLoginService.setEnabled(isEnabled)
            launchAtLoginEnabled = LaunchAtLoginService.isOnOrPendingApproval
            launchAtLoginPreference = launchAtLoginEnabled
            launchAtLoginStatusText = LaunchAtLoginService.statusText
            launchAtLoginError = nil
        } catch {
            launchAtLoginEnabled = LaunchAtLoginService.isOnOrPendingApproval
            launchAtLoginPreference = launchAtLoginEnabled
            launchAtLoginStatusText = LaunchAtLoginService.statusText
            launchAtLoginError = error.localizedDescription
        }
    }

    private func reloadWidgetsForSettingsChange() {
        WidgetCenter.shared.reloadTimelines(ofKind: "MacMonitorWidget")
    }
}

struct SettingsSectionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
    }
}

// MARK: - Visual Effect Background
struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject private var statsController: PulseStatsController
    @State private var selectedSize: WidgetSize = .medium

    enum WidgetSize: String, CaseIterable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"
    }

    var body: some View {
        ZStack {
            // Native macOS vibrancy background
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Title bar area
                titleBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Divider()
                    .padding(.horizontal, 20)

                // Size picker
                sizePicker
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                // Widget preview
                widgetPreview
                    .padding(.horizontal, 20)

                Spacer()

                // Footer instructions
                footer
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            statsController.refresh()
        }
    }

    // MARK: - Title Bar
    private var titleBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pulse")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Text("System Monitor")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Live indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)

                Text("Live")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Size Picker
    private var sizePicker: some View {
        Picker("Widget Size", selection: $selectedSize) {
            ForEach(WidgetSize.allCases, id: \.self) { size in
                Text(size.rawValue).tag(size)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 240)
    }

    // MARK: - Widget Preview
    private var widgetPreview: some View {
        Group {
            switch selectedSize {
            case .small:
                SmallWidgetView(stats: statsController.stats)
                    .frame(width: 170, height: 170)
            case .medium:
                MediumWidgetView(stats: statsController.stats)
                    .frame(width: 360, height: 170)
            case .large:
                LargeWidgetView(stats: statsController.stats)
                    .frame(width: 360, height: 380)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedSize)
    }

    // MARK: - Footer
    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "plus.square.on.square")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Text("Add to Notification Center")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Text("Click date in menu bar \u{2192} Edit Widgets")
                .font(.system(size: 11))
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
        }
    }
}
