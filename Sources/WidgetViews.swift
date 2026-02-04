import SwiftUI
import WidgetKit

// MARK: - Apple HIG Colors (Muted, purposeful)
struct AppColors {
    // Activity ring colors - muted, not harsh
    static let cpuGreen = Color(red: 0.35, green: 0.78, blue: 0.48)
    static let ramBlue = Color(red: 0.35, green: 0.68, blue: 0.95)
    static let diskAmber = Color(red: 0.95, green: 0.65, blue: 0.25)
    static let batteryGreen = Color(red: 0.35, green: 0.78, blue: 0.48)
    static let networkBlue = Color(red: 0.4, green: 0.6, blue: 0.95)
    static let networkGreen = Color(red: 0.35, green: 0.75, blue: 0.45)
    static let critical = Color(red: 0.95, green: 0.35, blue: 0.35)
}

// MARK: - Dynamic Color Based on Threshold (for battery/warnings)
func thresholdColor(for progress: Double) -> Color {
    let percentage = progress * 100
    if percentage < 50 {
        return AppColors.cpuGreen
    } else if percentage < 80 {
        return AppColors.diskAmber
    } else {
        return AppColors.critical
    }
}

// MARK: - Activity Ring (Apple Watch Style)
struct CircularProgressView: View {
    let progress: Double
    let icon: String
    let label: String
    let size: CGFloat
    var ringColor: Color = AppColors.cpuGreen

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Track (subtle)
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: size * 0.08)

                // Subtle glow
                Circle()
                    .trim(from: 0, to: clampedProgress)
                    .stroke(
                        ringColor.opacity(0.25),
                        style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 3)

                // Activity ring arc (thin, Apple Watch style)
                Circle()
                    .trim(from: 0, to: clampedProgress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Center content
                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.system(size: size * 0.18, weight: .medium))
                        .foregroundColor(ringColor.opacity(0.9))

                    Text("\(Int(clampedProgress * 100))%")
                        .font(.system(size: size * 0.22, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .frame(width: size, height: size)

            Text(label)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: size, alignment: .center)
                .lineLimit(1)
        }
        .frame(width: size)
    }
}

// MARK: - Battery View
struct BatteryView: View {
    let level: Int
    let isCharging: Bool

    var color: Color {
        if level <= 20 { return AppColors.critical }
        if level < 50 { return AppColors.diskAmber }
        return AppColors.batteryGreen
    }

    var icon: String {
        if isCharging { return "battery.100.bolt" }
        switch level {
        case 0..<10: return "battery.0"
        case 10..<25: return "battery.25"
        case 25..<50: return "battery.50"
        case 50..<75: return "battery.75"
        default: return "battery.100"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)

            Text("\(level)%")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

// MARK: - Network View
struct NetworkView: View {
    let up: Double
    let down: Double

    var body: some View {
        HStack(spacing: 8) {
            // Upload
            HStack(spacing: 3) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(AppColors.networkBlue)
                Text(formatSpeed(up))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }

            // Download
            HStack(spacing: 3) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(AppColors.networkGreen)
                Text(formatSpeed(down))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }

            Text("MB")
                .font(.system(size: 8, weight: .regular))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    func formatSpeed(_ speed: Double) -> String {
        let mbps = speed / 1024
        if mbps >= 100 {
            return String(format: "%.0f", mbps)
        } else if mbps >= 10 {
            return String(format: "%.0f", mbps)
        } else {
            return String(format: "%.1f", mbps)
        }
    }
}

// MARK: - Small Widget
struct SmallWidgetView: View {
    let stats: SystemStats

    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                BatteryView(level: stats.batteryLevel, isCharging: stats.isCharging)
                Spacer()
            }

            Spacer()

            // Activity Rings (distinct colors)
            HStack(spacing: 12) {
                CircularProgressView(
                    progress: stats.cpuUsage,
                    icon: "cpu",
                    label: "CPU",
                    size: 52,
                    ringColor: AppColors.cpuGreen
                )

                CircularProgressView(
                    progress: stats.memoryUsage,
                    icon: "memorychip",
                    label: "RAM",
                    size: 52,
                    ringColor: AppColors.ramBlue
                )
            }

            Spacer()

            // Network
            NetworkView(up: stats.networkUp, down: stats.networkDown)
        }
        .padding(14)
    }
}

// MARK: - Medium Widget
struct MediumWidgetView: View {
    let stats: SystemStats

    var body: some View {
        HStack(spacing: 16) {
            // Activity Rings (distinct colors)
            HStack(spacing: 12) {
                CircularProgressView(
                    progress: stats.cpuUsage,
                    icon: "cpu",
                    label: "CPU",
                    size: 48,
                    ringColor: AppColors.cpuGreen
                )

                CircularProgressView(
                    progress: stats.memoryUsage,
                    icon: "memorychip",
                    label: "RAM",
                    size: 48,
                    ringColor: AppColors.ramBlue
                )

                CircularProgressView(
                    progress: stats.diskUsage,
                    icon: "internaldrive",
                    label: "Disk",
                    size: 48,
                    ringColor: AppColors.diskAmber
                )
            }

            // Details
            VStack(alignment: .leading, spacing: 8) {
                BatteryView(level: stats.batteryLevel, isCharging: stats.isCharging)

                Spacer()

                // RAM row (blue to match ring)
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppColors.ramBlue)
                        .frame(width: 6, height: 6)
                    Text("RAM")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 28, alignment: .leading)
                    Spacer()
                    Text("\(String(format: "%.1f", stats.memoryUsed))/\(String(format: "%.0f", stats.memoryTotal))G")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .fixedSize()
                }

                // Disk row (amber to match ring)
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppColors.diskAmber)
                        .frame(width: 6, height: 6)
                    Text("Disk")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 28, alignment: .leading)
                    Spacer()
                    Text("\(String(format: "%.0f", stats.diskUsed))/\(String(format: "%.0f", stats.diskTotal))G")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .fixedSize()
                }

                Spacer()

                NetworkView(up: stats.networkUp, down: stats.networkDown)
            }
        }
        .padding(16)
    }
}

// MARK: - Large Widget
struct LargeWidgetView: View {
    let stats: SystemStats

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "gauge.with.dots.needle.50percent")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.ramBlue)

                    Text("Pulse")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }

                Spacer()

                BatteryView(level: stats.batteryLevel, isCharging: stats.isCharging)
            }

            // Activity Rings (distinct colors)
            HStack(spacing: 20) {
                CircularProgressView(
                    progress: stats.cpuUsage,
                    icon: "cpu",
                    label: "CPU",
                    size: 64,
                    ringColor: AppColors.cpuGreen
                )

                CircularProgressView(
                    progress: stats.memoryUsage,
                    icon: "memorychip",
                    label: "Memory",
                    size: 64,
                    ringColor: AppColors.ramBlue
                )

                CircularProgressView(
                    progress: stats.diskUsage,
                    icon: "internaldrive",
                    label: "Storage",
                    size: 64,
                    ringColor: AppColors.diskAmber
                )
            }

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            // Stats
            VStack(spacing: 10) {
                // Memory row with blue indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppColors.ramBlue)
                        .frame(width: 8, height: 8)
                    Text("Memory Used")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text(String(format: "%.1f / %.0f GB", stats.memoryUsed, stats.memoryTotal))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }

                // Storage row with amber indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppColors.diskAmber)
                        .frame(width: 8, height: 8)
                    Text("Storage Used")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text(String(format: "%.0f / %.0f GB", stats.diskUsed, stats.diskTotal))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }

                HStack {
                    Image(systemName: "network")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.networkBlue)

                    Text("Network")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()

                    NetworkView(up: stats.networkUp, down: stats.networkDown)
                }
            }

            // Apps
            if !stats.activeApps.isEmpty {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Running Apps")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))

                    HStack(spacing: 6) {
                        ForEach(stats.activeApps.prefix(4), id: \.self) { app in
                            Text(app)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
    }
}

// MARK: - Previews
struct WidgetViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SmallWidgetView(stats: .placeholder)
                .frame(width: 170, height: 170)
                .previewDisplayName("Small")

            MediumWidgetView(stats: .placeholder)
                .frame(width: 360, height: 170)
                .previewDisplayName("Medium")

            LargeWidgetView(stats: .placeholder)
                .frame(width: 360, height: 380)
                .previewDisplayName("Large")
        }
    }
}
