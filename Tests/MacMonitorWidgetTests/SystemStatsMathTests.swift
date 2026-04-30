import XCTest
@testable import MacMonitorWidget

final class SystemStatsMathTests: XCTestCase {
    func testCPUUsesDeltaBetweenSamples() {
        let previous = SystemStatsMath.CPUCounters(used: 100, total: 400)
        let current = SystemStatsMath.CPUCounters(used: 160, total: 500)

        XCTAssertEqual(
            SystemStatsMath.cpuUsage(previous: previous, current: current),
            0.6,
            accuracy: 0.0001
        )
    }

    func testCPUHandlesCounterReset() {
        let previous = SystemStatsMath.CPUCounters(used: 1_000, total: 4_000)
        let current = SystemStatsMath.CPUCounters(used: 40, total: 100)

        XCTAssertEqual(
            SystemStatsMath.cpuUsage(previous: previous, current: current),
            0.4,
            accuracy: 0.0001
        )
    }

    func testNetworkUsesOnlyStableInterfaces() {
        let start = Date()
        let previous = SystemStatsMath.NetworkCounters(
            interfaces: [
                "en0": .init(bytesIn: 1_000, bytesOut: 2_000),
                "en5": .init(bytesIn: 8_000, bytesOut: 16_000)
            ],
            date: start
        )
        let current = SystemStatsMath.NetworkCounters(
            interfaces: [
                "en0": .init(bytesIn: 3_048, bytesOut: 4_048),
                "en7": .init(bytesIn: 50_000, bytesOut: 50_000)
            ],
            date: start.addingTimeInterval(2)
        )

        let speed = SystemStatsMath.networkSpeed(previous: previous, current: current)

        XCTAssertEqual(speed.down, 1.0, accuracy: 0.0001)
        XCTAssertEqual(speed.up, 1.0, accuracy: 0.0001)
    }

    func testNetworkIgnoresResetInterfaces() {
        let start = Date()
        let previous = SystemStatsMath.NetworkCounters(
            interfaces: ["en0": .init(bytesIn: 10_000, bytesOut: 10_000)],
            date: start
        )
        let current = SystemStatsMath.NetworkCounters(
            interfaces: ["en0": .init(bytesIn: 500, bytesOut: 500)],
            date: start.addingTimeInterval(1)
        )

        let speed = SystemStatsMath.networkSpeed(previous: previous, current: current)

        XCTAssertEqual(speed.down, 0, accuracy: 0.0001)
        XCTAssertEqual(speed.up, 0, accuracy: 0.0001)
    }

    func testNetworkIgnoresTooShortSampleWindows() {
        let start = Date()
        let previous = SystemStatsMath.NetworkCounters(
            interfaces: ["en0": .init(bytesIn: 1_000, bytesOut: 1_000)],
            date: start
        )
        let current = SystemStatsMath.NetworkCounters(
            interfaces: ["en0": .init(bytesIn: 10_000, bytesOut: 10_000)],
            date: start.addingTimeInterval(0.1)
        )

        let speed = SystemStatsMath.networkSpeed(previous: previous, current: current)

        XCTAssertEqual(speed.down, 0, accuracy: 0.0001)
        XCTAssertEqual(speed.up, 0, accuracy: 0.0001)
    }
}
