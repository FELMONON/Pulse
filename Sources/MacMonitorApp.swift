import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct MacMonitorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 420, height: 480)
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
    @State private var stats = SystemStats.placeholder
    @State private var selectedSize: WidgetSize = .medium

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
        .onReceive(timer) { _ in
            stats = SystemMonitor.shared.getStats()
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
                SmallWidgetView(stats: stats)
                    .frame(width: 170, height: 170)
            case .medium:
                MediumWidgetView(stats: stats)
                    .frame(width: 360, height: 170)
            case .large:
                LargeWidgetView(stats: stats)
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
