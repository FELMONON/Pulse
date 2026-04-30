import Foundation
import IOKit
import IOKit.ps
import AppKit

// MARK: - System Statistics Model
struct SystemStats: Codable {
    var cpuUsage: Double
    var memoryUsage: Double
    var memoryUsed: Double // GB
    var memoryTotal: Double // GB
    var diskUsage: Double
    var diskUsed: Double // GB
    var diskTotal: Double // GB
    var diskAvailable: Double // GB
    var diskPurgeable: Double // GB
    var batteryLevel: Int
    var isCharging: Bool
    var hasBattery: Bool
    var networkUp: Double // KB/s
    var networkDown: Double // KB/s
    var activeApps: [String]
    var timestamp: Date

    var isStale: Bool {
        Date().timeIntervalSince(timestamp) > 120
    }

    static var placeholder: SystemStats {
        SystemStats(
            cpuUsage: 0.45,
            memoryUsage: 0.62,
            memoryUsed: 10.2,
            memoryTotal: 16.0,
            diskUsage: 0.58,
            diskUsed: 234.5,
            diskTotal: 512.0,
            diskAvailable: 277.5,
            diskPurgeable: 0,
            batteryLevel: 78,
            isCharging: true,
            hasBattery: true,
            networkUp: 125.4,
            networkDown: 892.1,
            activeApps: ["Safari", "Xcode", "Slack"],
            timestamp: Date()
        )
    }
}

// MARK: - Shared Stats Cache
enum SystemStatsCache {
    private static let appGroupID = "group.com.macmonitor.widget.shared"
    private static let legacySuiteName = "com.macmonitor.widget.shared"
    private static let statsKey = "latestSystemStats"

    private static let defaults: UserDefaults = {
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil,
           let groupDefaults = UserDefaults(suiteName: appGroupID) {
            return groupDefaults
        }

        return UserDefaults(suiteName: legacySuiteName) ?? .standard
    }()

    static func save(_ stats: SystemStats) {
        guard let data = try? JSONEncoder().encode(stats) else {
            return
        }

        defaults.set(data, forKey: statsKey)
        defaults.synchronize()
    }

    static func load(maxAge: TimeInterval) -> SystemStats? {
        guard let data = defaults.data(forKey: statsKey),
              let stats = try? JSONDecoder().decode(SystemStats.self, from: data) else {
            return nil
        }

        let age = Date().timeIntervalSince(stats.timestamp)
        guard age >= 0 && age <= maxAge else {
            return nil
        }

        return stats
    }
}

// MARK: - Testable Math
enum SystemStatsMath {
    struct CPUCounters: Equatable {
        let used: UInt64
        let total: UInt64
    }

    struct NetworkInterfaceCounters: Equatable {
        let bytesIn: UInt64
        let bytesOut: UInt64
    }

    struct NetworkCounters: Equatable {
        let interfaces: [String: NetworkInterfaceCounters]
        let date: Date
    }

    static func cpuUsage(previous: CPUCounters?, current: CPUCounters) -> Double {
        guard current.total > 0 else {
            return 0
        }

        guard let previous,
              current.total >= previous.total,
              current.used >= previous.used else {
            return clamp(Double(current.used) / Double(current.total))
        }

        let totalDelta = current.total - previous.total
        guard totalDelta > 0 else {
            return 0
        }

        let usedDelta = current.used - previous.used
        return clamp(Double(usedDelta) / Double(totalDelta))
    }

    static func networkSpeed(
        previous: NetworkCounters?,
        current: NetworkCounters,
        minimumInterval: TimeInterval = 0.2
    ) -> (up: Double, down: Double) {
        guard let previous else {
            return (0, 0)
        }

        let timeDiff = current.date.timeIntervalSince(previous.date)
        guard timeDiff > minimumInterval else {
            return (0, 0)
        }

        var bytesInDelta: UInt64 = 0
        var bytesOutDelta: UInt64 = 0

        for (name, currentCounters) in current.interfaces {
            guard let previousCounters = previous.interfaces[name],
                  currentCounters.bytesIn >= previousCounters.bytesIn,
                  currentCounters.bytesOut >= previousCounters.bytesOut else {
                continue
            }

            bytesInDelta += currentCounters.bytesIn - previousCounters.bytesIn
            bytesOutDelta += currentCounters.bytesOut - previousCounters.bytesOut
        }

        return (
            up: Double(bytesOutDelta) / timeDiff / 1024,
            down: Double(bytesInDelta) / timeDiff / 1024
        )
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

// MARK: - System Monitor
class SystemMonitor {
    static let shared = SystemMonitor()

    private var previousCPUCounters: SystemStatsMath.CPUCounters?
    private var previousNetworkCounters: SystemStatsMath.NetworkCounters?

    func getCachedStats(maxAge: TimeInterval = 120) -> SystemStats? {
        SystemStatsCache.load(maxAge: maxAge)
    }

    func getStatsAndCache() -> SystemStats {
        let stats = getStats()
        SystemStatsCache.save(stats)
        return stats
    }

    func getStats() -> SystemStats {
        // Cache results to avoid multiple calls
        let memory = getMemoryUsage()
        let disk = getDiskUsage()
        let battery = getBatteryLevel()
        let network = getNetworkSpeed()

        return SystemStats(
            cpuUsage: getCPUUsage(),
            memoryUsage: memory.percentage,
            memoryUsed: memory.used,
            memoryTotal: memory.total,
            diskUsage: disk.percentage,
            diskUsed: disk.used,
            diskTotal: disk.total,
            diskAvailable: disk.available,
            diskPurgeable: disk.purgeable,
            batteryLevel: battery.level,
            isCharging: battery.isCharging,
            hasBattery: battery.hasBattery,
            networkUp: network.up,
            networkDown: network.down,
            activeApps: getActiveApps(),
            timestamp: Date()
        )
    }

    // MARK: - CPU Usage
    private func getCPUUsage() -> Double {
        guard let current = getCPUCounters(), current.total > 0 else {
            return 0.0
        }

        defer {
            previousCPUCounters = current
        }

        return SystemStatsMath.cpuUsage(previous: previousCPUCounters, current: current)
    }

    private func getCPUCounters() -> SystemStatsMath.CPUCounters? {
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let err = host_processor_info(mach_host_self(),
                                       PROCESSOR_CPU_LOAD_INFO,
                                       &numCPUs,
                                       &cpuInfo,
                                       &numCpuInfo)

        guard err == KERN_SUCCESS, let info = cpuInfo, numCPUs > 0 else {
            return nil
        }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: info),
                vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }

        var usedTicks: UInt64 = 0
        var totalTicks: UInt64 = 0

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = UInt64(Int64(max(info[offset + Int(CPU_STATE_USER)], 0)))
            let system = UInt64(Int64(max(info[offset + Int(CPU_STATE_SYSTEM)], 0)))
            let idle = UInt64(Int64(max(info[offset + Int(CPU_STATE_IDLE)], 0)))
            let nice = UInt64(Int64(max(info[offset + Int(CPU_STATE_NICE)], 0)))

            usedTicks += user + system + nice
            totalTicks += user + system + idle + nice
        }

        return SystemStatsMath.CPUCounters(used: usedTicks, total: totalTicks)
    }

    // MARK: - Memory Usage
    private func getMemoryUsage() -> (percentage: Double, used: Double, total: Double) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (0, 0, 0)
        }

        let pageSize = Double(vm_kernel_page_size)
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)

        let activeMemory = Double(stats.active_count) * pageSize
        let wiredMemory = Double(stats.wire_count) * pageSize
        let compressedMemory = Double(stats.compressor_page_count) * pageSize

        let usedMemory = activeMemory + wiredMemory + compressedMemory
        let percentage = usedMemory / totalMemory

        return (min(percentage, 1.0), usedMemory / 1_073_741_824, totalMemory / 1_073_741_824)
    }

    // MARK: - Disk Usage
    private func getDiskUsage() -> (percentage: Double, used: Double, total: Double, available: Double, purgeable: Double) {
        do {
            let fileURL = URL(fileURLWithPath: "/")
            let values = try fileURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])

            if let total = values.volumeTotalCapacity {
                let freeBytes = Double(values.volumeAvailableCapacity ?? 0)
                let importantAvailableBytes = values.volumeAvailableCapacityForImportantUsage.map(Double.init) ?? freeBytes
                let totalGB = Double(total) / 1_000_000_000
                let freeGB = freeBytes / 1_000_000_000
                let usedGB = max(totalGB - freeGB, 0)
                let purgeableGB = max((importantAvailableBytes - freeBytes) / 1_000_000_000, 0)
                let percentage = totalGB > 0 ? usedGB / totalGB : 0
                return (min(max(percentage, 0), 1), usedGB, totalGB, freeGB, purgeableGB)
            }
        } catch {}

        return (0, 0, 0, 0, 0)
    }

    // MARK: - Battery
    private func getBatteryLevel() -> (level: Int, isCharging: Bool, hasBattery: Bool) {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

        for source in sources {
            if let info = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] {
                if let capacity = info[kIOPSCurrentCapacityKey] as? Int,
                   let isCharging = info[kIOPSIsChargingKey] as? Bool {
                    return (capacity, isCharging, true)
                }
            }
        }

        return (0, false, false)
    }

    // MARK: - Network Speed
    private func getNetworkSpeed() -> (up: Double, down: Double) {
        guard let current = getNetworkCounters() else {
            return (0, 0)
        }

        defer {
            previousNetworkCounters = current
        }

        return SystemStatsMath.networkSpeed(previous: previousNetworkCounters, current: current)
    }

    private func getNetworkCounters() -> SystemStatsMath.NetworkCounters? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        defer { freeifaddrs(ifaddr) }

        var interfaces: [String: SystemStatsMath.NetworkInterfaceCounters] = [:]

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let currentPtr = ptr {
            defer {
                ptr = currentPtr.pointee.ifa_next
            }

            let interface = currentPtr.pointee
            guard let address = interface.ifa_addr,
                  address.pointee.sa_family == sa_family_t(AF_LINK) else {
                continue
            }

            let flags = Int32(interface.ifa_flags)
            guard (flags & IFF_UP) != 0,
                  (flags & IFF_RUNNING) != 0,
                  (flags & IFF_LOOPBACK) == 0 else {
                continue
            }

            let name = String(cString: interface.ifa_name)
            guard !name.hasPrefix("awdl"),
                  !name.hasPrefix("llw"),
                  !name.hasPrefix("utun"),
                  !name.hasPrefix("gif"),
                  !name.hasPrefix("stf") else {
                continue
            }

            if let data = interface.ifa_data {
                let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                let existing = interfaces[name] ?? SystemStatsMath.NetworkInterfaceCounters(bytesIn: 0, bytesOut: 0)
                interfaces[name] = SystemStatsMath.NetworkInterfaceCounters(
                    bytesIn: existing.bytesIn + UInt64(networkData.ifi_ibytes),
                    bytesOut: existing.bytesOut + UInt64(networkData.ifi_obytes)
                )
            }
        }

        return SystemStatsMath.NetworkCounters(interfaces: interfaces, date: Date())
    }

    // MARK: - Active Apps
    private func getActiveApps() -> [String] {
        let workspace = NSWorkspace.shared
        let apps = workspace.runningApplications
            .filter { $0.activationPolicy == .regular && $0.isActive == false }
            .prefix(5)
            .compactMap { $0.localizedName }

        if let frontmost = workspace.frontmostApplication?.localizedName {
            return [frontmost] + apps.filter { $0 != frontmost }
        }

        return Array(apps)
    }
}
