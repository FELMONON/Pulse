import Foundation
import IOKit
import IOKit.ps
import AppKit

// MARK: - System Statistics Model
struct SystemStats {
    var cpuUsage: Double
    var memoryUsage: Double
    var memoryUsed: Double // GB
    var memoryTotal: Double // GB
    var diskUsage: Double
    var diskUsed: Double // GB
    var diskTotal: Double // GB
    var batteryLevel: Int
    var isCharging: Bool
    var networkUp: Double // KB/s
    var networkDown: Double // KB/s
    var activeApps: [String]
    var timestamp: Date

    static var placeholder: SystemStats {
        SystemStats(
            cpuUsage: 0.45,
            memoryUsage: 0.62,
            memoryUsed: 10.2,
            memoryTotal: 16.0,
            diskUsage: 0.58,
            diskUsed: 234.5,
            diskTotal: 512.0,
            batteryLevel: 78,
            isCharging: true,
            networkUp: 125.4,
            networkDown: 892.1,
            activeApps: ["Safari", "Xcode", "Slack"],
            timestamp: Date()
        )
    }
}

// MARK: - System Monitor
class SystemMonitor {
    static let shared = SystemMonitor()

    // Use UserDefaults to persist network data between widget refreshes
    private let defaults = UserDefaults(suiteName: "com.macmonitor.widget.shared") ?? .standard

    private var previousNetworkIn: UInt64 {
        get { UInt64(defaults.integer(forKey: "previousNetworkIn")) }
        set { defaults.set(Int(newValue), forKey: "previousNetworkIn") }
    }
    private var previousNetworkOut: UInt64 {
        get { UInt64(defaults.integer(forKey: "previousNetworkOut")) }
        set { defaults.set(Int(newValue), forKey: "previousNetworkOut") }
    }
    private var lastNetworkCheck: Date {
        get { defaults.object(forKey: "lastNetworkCheck") as? Date ?? Date() }
        set { defaults.set(newValue, forKey: "lastNetworkCheck") }
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
            batteryLevel: battery.level,
            isCharging: battery.isCharging,
            networkUp: network.up,
            networkDown: network.down,
            activeApps: getActiveApps(),
            timestamp: Date()
        )
    }

    // MARK: - CPU Usage
    private func getCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let err = host_processor_info(mach_host_self(),
                                       PROCESSOR_CPU_LOAD_INFO,
                                       &numCPUs,
                                       &cpuInfo,
                                       &numCpuInfo)

        guard err == KERN_SUCCESS, let info = cpuInfo else {
            return 0.0
        }

        var totalUsage: Double = 0

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = Double(info[offset + Int(CPU_STATE_USER)])
            let system = Double(info[offset + Int(CPU_STATE_SYSTEM)])
            let idle = Double(info[offset + Int(CPU_STATE_IDLE)])
            let nice = Double(info[offset + Int(CPU_STATE_NICE)])

            let total = user + system + idle + nice
            let used = user + system + nice

            if total > 0 {
                totalUsage += used / total
            }
        }

        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride))

        return min(totalUsage / Double(numCPUs), 1.0)
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
    private func getDiskUsage() -> (percentage: Double, used: Double, total: Double) {
        do {
            let fileURL = URL(fileURLWithPath: "/")
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])

            if let total = values.volumeTotalCapacity,
               let available = values.volumeAvailableCapacityForImportantUsage {
                let totalGB = Double(total) / 1_000_000_000
                let usedGB = totalGB - (Double(available) / 1_000_000_000)
                return (usedGB / totalGB, usedGB, totalGB)
            }
        } catch {}

        return (0, 0, 0)
    }

    // MARK: - Battery
    private func getBatteryLevel() -> (level: Int, isCharging: Bool) {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

        for source in sources {
            if let info = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] {
                if let capacity = info[kIOPSCurrentCapacityKey] as? Int,
                   let isCharging = info[kIOPSIsChargingKey] as? Bool {
                    return (capacity, isCharging)
                }
            }
        }

        return (100, false)
    }

    // MARK: - Network Speed
    private func getNetworkSpeed() -> (up: Double, down: Double) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return (0, 0)
        }
        defer { freeifaddrs(ifaddr) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var ptr = firstAddr
        while true {
            let interface = ptr.pointee
            let name = String(cString: interface.ifa_name)

            if name.hasPrefix("en") || name.hasPrefix("lo") {
                if let data = interface.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                    totalIn += UInt64(networkData.ifi_ibytes)
                    totalOut += UInt64(networkData.ifi_obytes)
                }
            }

            guard let next = interface.ifa_next else { break }
            ptr = next
        }

        let now = Date()
        let timeDiff = now.timeIntervalSince(lastNetworkCheck)

        var speedIn: Double = 0
        var speedOut: Double = 0

        if timeDiff > 0 && previousNetworkIn > 0 {
            speedIn = Double(totalIn - previousNetworkIn) / timeDiff / 1024
            speedOut = Double(totalOut - previousNetworkOut) / timeDiff / 1024
        }

        previousNetworkIn = totalIn
        previousNetworkOut = totalOut
        lastNetworkCheck = now

        return (max(speedOut, 0), max(speedIn, 0))
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
